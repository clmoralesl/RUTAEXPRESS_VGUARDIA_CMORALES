# ==============================================================================
# Script de Inyeccion Segura de Oracle Cloud Wallet a ec2-apps
# ==============================================================================

param(
    [string]$KeyPath = "$HOME/Downloads/labsuser.pem",
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

if (-not (Test-Path $KeyPath)) {
    $altKey = Join-Path $HOME "Downloads/vockey.pem"
    if (Test-Path $altKey) {
        $KeyPath = $altKey
    } else {
        $altKey2 = Join-Path $HOME "Downloads/devops_key_cm_vg.pem"
        if (Test-Path $altKey2) {
            $KeyPath = $altKey2
        } else {
            Write-Error "No se encontro la llave privada SSH en $KeyPath. Especifique el parametro -KeyPath."
            exit 1
        }
    }
}

Write-Host "Inyectando Oracle Wallet en $Ec2Host utilizando la llave $KeyPath..." -ForegroundColor Green

# 1. Copiar archivo comprimido hacia directorio temporal
& scp -o StrictHostKeyChecking=no -i "$KeyPath" "$zipPath" "ubuntu@${Ec2Host}:/tmp/Wallet_rutaexpressdb.zip"

# 2. Descomprimir y aplicar permisos 600
$remoteCmd = "sudo mkdir -p /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet && " + `
             "sudo unzip -o /tmp/Wallet_rutaexpressdb.zip -d /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet && " + `
             "sudo chmod -R 600 /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet/* && " + `
             "sudo rm -f /tmp/Wallet_rutaexpressdb.zip && " + `
             "echo 'Wallet desplegado exitosamente en el servidor.'"

& ssh -o StrictHostKeyChecking=no -i "$KeyPath" "ubuntu@${Ec2Host}" "$remoteCmd"

Write-Host "Oracle Wallet inyectado y protegido con permisos 600." -ForegroundColor Green
