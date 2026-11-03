# ==============================================================================
# Script de Inyeccion Segura de Oracle Cloud Wallet a ec2-apps
# ==============================================================================

param(
    [string]$KeyPath = "",
    [string]$Ec2Host = ""
)

# "Stop" aplica solo a los cmdlets de PowerShell. Los programas externos
# (terraform, scp, ssh) se ejecutan con Invoke-ComandoNativo, que decide el
# resultado por el codigo de salida y no por lo que escriben en stderr.
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zipPath   = Join-Path $scriptDir "../oracle/Wallet_rutaexpressdb.zip"

$walletDir   = "/opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet"
$composeFile = "/opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/apps/compose.yml"
$servicios   = @(
    "ms-rutaexpress-envios",
    "ms-rutaexpress-catalogo",
    "ms-rutaexpress-auditoria",
    "ms-rutaexpress-bff"
)

# Ejecuta un programa externo sin que su salida de error aborte el script.
# En Windows PowerShell 5.1, con ErrorActionPreference = "Stop", cada linea que
# un programa externo escribe en stderr (por ejemplo, el progreso de
# "docker compose" o los avisos de ssh) se convierte en NativeCommandError y
# detiene el script aunque el programa termine bien. Dentro de esta funcion la
# preferencia es local y vale "Continue"; el exito se mide con $LASTEXITCODE.
# Con -Capturar devuelve las lineas de stdout en lugar de mostrarlas.
function Invoke-ComandoNativo {
    param(
        [Parameter(Mandatory = $true)] [string]$Descripcion,
        [Parameter(Mandatory = $true)] [scriptblock]$Comando,
        [switch]$Capturar
    )

    $ErrorActionPreference = "Continue"

    $salida = & $Comando 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord] -or -not $Capturar) {
            Write-Host "$_"
        } else {
            "$_"
        }
    }
    $codigo = $LASTEXITCODE

    if ($codigo -ne 0) {
        Write-Host "ERROR: fallo el paso '$Descripcion' (codigo de salida $codigo)." -ForegroundColor Red
        exit $codigo
    }

    if ($Capturar) {
        return $salida
    }
}

if (-not (Test-Path $zipPath)) {
    Write-Error "No se encontro el archivo Wallet_rutaexpressdb.zip en infra/oracle/"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Ec2Host)) {
    Write-Host "Obteniendo IP publica de ec2-apps desde Terraform..." -ForegroundColor Cyan
    $Ec2Host = Invoke-ComandoNativo -Descripcion "terraform output" -Capturar -Comando {
        & terraform -chdir="$scriptDir" output -raw ec2_apps_public_ip
    }
    $Ec2Host = "$Ec2Host".Trim()
    if ([string]::IsNullOrWhiteSpace($Ec2Host)) {
        Write-Error "Terraform no devolvio la IP de ec2-apps. Especifique el parametro -Ec2Host."
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($KeyPath) -or -not (Test-Path $KeyPath)) {
    $defaultKey = Join-Path $scriptDir "../labsuser.pem"
    if (Test-Path $defaultKey) {
        $KeyPath = $defaultKey
    } else {
        $altKey = Join-Path $HOME "Downloads/labsuser.pem"
        if (Test-Path $altKey) {
            $KeyPath = $altKey
        } else {
            $altKey2 = Join-Path $HOME "Downloads/vockey.pem"
            if (Test-Path $altKey2) {
                $KeyPath = $altKey2
            } else {
                Write-Error "No se encontro la llave privada SSH en $KeyPath ni en infra/labsuser.pem. Especifique el parametro -KeyPath."
                exit 1
            }
        }
    }
}

Write-Host "Inyectando Oracle Wallet en $Ec2Host utilizando la llave $KeyPath..." -ForegroundColor Green

# 1. Copiar archivo comprimido hacia directorio temporal
Invoke-ComandoNativo -Descripcion "copia del wallet por scp" -Comando {
    & scp -o StrictHostKeyChecking=no -i "$KeyPath" "$zipPath" "ubuntu@${Ec2Host}:/tmp/Wallet_rutaexpressdb.zip"
}

# 2. Descomprimir, aplicar permisos 755/644 y recrear servicios dependientes.
#    "2>&1" envia el progreso de docker compose a stdout en el propio servidor.
#    "--no-build" reutiliza las imagenes construidas por bootstrap-apps.sh y
#    "--force-recreate" garantiza que los contenedores se reinicien y lean el wallet.
$remoteCmd = "sudo mkdir -p $walletDir && " + `
             "sudo unzip -o /tmp/Wallet_rutaexpressdb.zip -d $walletDir && " + `
             "sudo chmod 755 $walletDir && " + `
             "sudo chmod 644 $walletDir/* && " + `
             "sudo rm -f /tmp/Wallet_rutaexpressdb.zip && " + `
             "echo 'Wallet desplegado. Recreando microservicios dependientes de Oracle...' && " + `
             "sudo docker compose -f $composeFile up -d --no-build --force-recreate $($servicios -join ' ') 2>&1"

Invoke-ComandoNativo -Descripcion "descompresion del wallet y recreacion de servicios por ssh" -Comando {
    & ssh -o StrictHostKeyChecking=no -i "$KeyPath" "ubuntu@${Ec2Host}" "$remoteCmd"
}

# 3. Verificar que los cuatro contenedores esten en ejecucion con su nombre normal.
#    Un nombre temporal (<id>_ms-rutaexpress-...) indica una recreacion interrumpida.
Write-Host "Verificando el estado de los microservicios..." -ForegroundColor Cyan
$estado = Invoke-ComandoNativo -Descripcion "consulta de contenedores por ssh" -Capturar -Comando {
    & ssh -o StrictHostKeyChecking=no -i "$KeyPath" "ubuntu@${Ec2Host}" "sudo docker ps -a --format '{{.Names}} {{.Status}}'"
}

$fallidos = @()
foreach ($servicio in $servicios) {
    $linea = @($estado) | Where-Object { $_ -match "^$([regex]::Escape($servicio)) Up" }
    if ($linea) {
        Write-Host "  OK      $servicio" -ForegroundColor Green
    } else {
        Write-Host "  DETENIDO o AUSENTE  $servicio" -ForegroundColor Red
        $fallidos += $servicio
    }
}

if ($fallidos.Count -gt 0) {
    Write-Host "ERROR: $($fallidos.Count) microservicio(s) no quedaron en ejecucion: $($fallidos -join ', ')." -ForegroundColor Red
    Write-Host "Recuperacion: ver la seccion 'Recuperacion tras una inyeccion interrumpida' de infra/aws-ec2/README.md." -ForegroundColor Yellow
    exit 2
}

Write-Host "Oracle Wallet inyectado y microservicios sincronizados." -ForegroundColor Green
