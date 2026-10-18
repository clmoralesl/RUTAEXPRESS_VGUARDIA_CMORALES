# ==============================================================================
# Generacion de Certificado SSL Autofirmado para Desarrollo Local (RutaExpress)
# ==============================================================================

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$certFile = Join-Path $scriptDir "localhost.crt"
$keyFile  = Join-Path $scriptDir "localhost.key"
$cnfFile  = Join-Path $scriptDir "openssl.cnf"

Write-Host "Generando configuracion OpenSSL temporal en $cnfFile..." -ForegroundColor Cyan

$configContent = @"
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[dn]
C  = CL
ST = Region Metropolitana
L  = Santiago
O  = RutaExpress SaaS
OU = DevOps
CN = localhost

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1  = 127.0.0.1
IP.2  = ::1
"@

Set-Content -Path $cnfFile -Value $configContent -Encoding ASCII

# Ubicacion de OpenSSL (Git for Windows o PATH)
$opensslCmd = "openssl"
if (-not (Get-Command "openssl" -ErrorAction SilentlyContinue)) {
    $gitOpenSsl = "C:\Program Files\Git\usr\bin\openssl.exe"
    if (Test-Path $gitOpenSsl) {
        $opensslCmd = $gitOpenSsl
    } else {
        Write-Error "No se encontro OpenSSL en el sistema. Asegurese de tener Git for Windows instalado."
        exit 1
    }
}

Write-Host "Ejecutando OpenSSL ($opensslCmd)..." -ForegroundColor Cyan

& $opensslCmd req -x509 -nodes -days 365 -newkey rsa:2048 `
    -keyout $keyFile `
    -out $certFile `
    -config $cnfFile `
    -extensions req_ext

if ((Test-Path $certFile) -and (Test-Path $keyFile)) {
    Write-Host "Certificados SSL generados exitosamente:" -ForegroundColor Green
    Write-Host "  - Certificado: $certFile" -ForegroundColor Gray
    Write-Host "  - Clave privada: $keyFile" -ForegroundColor Gray
} else {
    Write-Error "Fallo en la generacion de certificados SSL."
}

if (Test-Path $cnfFile) {
    Remove-Item $cnfFile -Force
}
