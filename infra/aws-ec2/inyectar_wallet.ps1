# ==============================================================================
# Script de Inyeccion Segura de Oracle Cloud Wallet a ec2-apps
# ==============================================================================

param(
    [string]$KeyPath = "",
    [string]$Ec2Host = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zipPath   = Join-Path $scriptDir "../oracle/Wallet_rutaexpressdb.zip"

if (-not (Test-Path $zipPath)) {
    Write-Error "No se encontro el archivo Wallet_rutaexpressdb.zip en infra/oracle/"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Ec2Host)) {
    Write-Host "Obteniendo IP publica de ec2-apps desde Terraform..." -ForegroundColor Cyan
    $Ec2Host = & terraform -chdir="$scriptDir" output -raw ec2_apps_public_ip
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
& scp -o StrictHostKeyChecking=no -i "$KeyPath" "$zipPath" "ubuntu@${Ec2Host}:/tmp/Wallet_rutaexpressdb.zip"

# 2. Descomprimir, aplicar permisos 755/644 y reiniciar servicios dependientes
$remoteCmd = "sudo mkdir -p /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet && " + `
             "sudo unzip -o /tmp/Wallet_rutaexpressdb.zip -d /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet && " + `
             "sudo chmod 755 /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet && " + `
             "sudo chmod 644 /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet/* && " + `
             "sudo rm -f /tmp/Wallet_rutaexpressdb.zip && " + `
             "echo 'Wallet desplegado. Reiniciando microservicios dependientes de Oracle...' && " + `
             "sudo docker compose -f /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/apps/compose.yml restart ms-rutaexpress-envios ms-rutaexpress-catalogo ms-rutaexpress-auditoria ms-rutaexpress-bff && " + `
             "echo 'Microservicios reconectados exitosamente a Oracle Cloud.'"

& ssh -o StrictHostKeyChecking=no -i "$KeyPath" "ubuntu@${Ec2Host}" "$remoteCmd"

Write-Host "Oracle Wallet inyectado y microservicios sincronizados." -ForegroundColor Green
