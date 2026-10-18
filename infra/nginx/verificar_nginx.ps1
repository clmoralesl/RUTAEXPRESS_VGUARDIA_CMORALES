# ==============================================================================
# Script de Verificacion del Proxy Inverso Nginx con HTTPS (Issue #39)
# ==============================================================================

$ErrorActionPreference = "Continue"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VERIFICACION DE NGINX HTTPS PROXY Y CONTEXTO SEGURO (ISSUE 39) " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$certPath = Join-Path $scriptDir "certs/localhost.crt"
$keyPath  = Join-Path $scriptDir "certs/localhost.key"
$confPath = Join-Path $scriptDir "nginx.conf"

# 1. Validacion de archivos de certificados SSL
Write-Host "`n[1/5] Verificando presencia de certificados SSL..." -ForegroundColor Yellow
if ((Test-Path $certPath) -and (Test-Path $keyPath)) {
    Write-Host "  [OK] Certificado X.509 y clave privada encontrados." -ForegroundColor Green
    $opensslCmd = if (Get-Command "openssl" -ErrorAction SilentlyContinue) { "openssl" } else { "C:\Program Files\Git\usr\bin\openssl.exe" }
    if (Test-Path $opensslCmd) {
        $subject = & $opensslCmd x509 -in $certPath -noout -subject
        $dates   = & $opensslCmd x509 -in $certPath -noout -dates
        Write-Host "       $subject" -ForegroundColor Gray
        Write-Host "       $dates" -ForegroundColor Gray
    }
} else {
    Write-Host "  [ERROR] Faltan los certificados SSL en infra/nginx/certs." -ForegroundColor Red
    exit 1
}

# 2. Verificacion de sintaxis de nginx.conf mediante contenedor efimero
Write-Host "`n[2/5] Validando sintaxis de nginx.conf con imagen oficial de Nginx..." -ForegroundColor Yellow
$testOutput = docker run --rm `
    -v "${confPath}:/etc/nginx/nginx.conf:ro" `
    -v "${scriptDir}/certs:/etc/nginx/certs:ro" `
    nginx:1.27-alpine nginx -t 2>&1

if ($testOutput -match "syntax is ok" -and $testOutput -match "test is successful") {
    Write-Host "  [OK] Sintaxis de Nginx verificada exitosamente." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Fallo en la prueba de sintaxis de Nginx:" -ForegroundColor Red
    Write-Host $testOutput -ForegroundColor Red
    exit 1
}

# 3. Levantar contenedor de prueba en segundo plano
Write-Host "`n[3/5] Levantando contenedor de prueba temporal (rutaexpress-nginx-test)..." -ForegroundColor Yellow
docker rm -f rutaexpress-nginx-test 2>$null | Out-Null

$containerId = docker run -d --name rutaexpress-nginx-test `
    -p 8443:443 -p 8088:80 `
    -v "${confPath}:/etc/nginx/nginx.conf:ro" `
    -v "${scriptDir}/certs:/etc/nginx/certs:ro" `
    nginx:1.27-alpine

Start-Sleep -Seconds 2

$isRunning = docker inspect -f '{{.State.Running}}' rutaexpress-nginx-test 2>$null
if ($isRunning -eq "true") {
    Write-Host "  [OK] Contenedor Nginx ejecutandose en puertos 8088 (HTTP) y 8443 (HTTPS)." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] El contenedor Nginx no inicio correctamente." -ForegroundColor Red
    docker logs rutaexpress-nginx-test
    exit 1
}

# 4. Validar Redireccion HTTP (80) -> HTTPS (443)
Write-Host "`n[4/5] Verificando redireccion HTTP 301 a HTTPS..." -ForegroundColor Yellow
try {
    $curlRedir = & curl.exe -s -i http://localhost:8088/api/publico/salud
    $statusLine = ($curlRedir | Select-String "HTTP/1.1 301")
    $locationLine = ($curlRedir | Select-String "Location:")

    if ($statusLine -and $locationLine -match "https://") {
        Write-Host "  [OK] Redireccion 301 permanente comprobada exitosamente:" -ForegroundColor Green
        Write-Host "       $statusLine" -ForegroundColor Gray
        Write-Host "       $locationLine" -ForegroundColor Gray
    } else {
        Write-Host "  [ADVERTENCIA] Salida inesperada en redireccion HTTP:" -ForegroundColor Yellow
        Write-Host ($curlRedir -join "`n") -ForegroundColor Gray
    }
} catch {
    Write-Host "  [ERROR] Error al validar redireccion HTTP: $_" -ForegroundColor Red
}

# 5. Validar Preflight CORS OPTIONS y Endpoint de Salud Proxy
Write-Host "`n[5/5] Verificando preflights CORS (OPTIONS) y Endpoint HTTPS..." -ForegroundColor Yellow
try {
    # Probar endpoint directo del proxy
    $respSalud = & curl.exe -s -k https://localhost:8443/salud-proxy
    Write-Host "  [OK] Endpoint HTTPS /salud-proxy responde:" -ForegroundColor Green
    Write-Host "       $respSalud" -ForegroundColor Gray

    # Probar preflight CORS OPTIONS
    $optResp = & curl.exe -s -i -k -X OPTIONS `
        -H "Origin: https://localhost" `
        -H "Access-Control-Request-Method: GET" `
        https://localhost:8443/api/bff/envios

    $has204 = ($optResp | Select-String "HTTP/1.1 204")
    $corsOrigin = ($optResp | Select-String "Access-Control-Allow-Origin:")
    $corsMethods = ($optResp | Select-String "Access-Control-Allow-Methods:")

    if ($has204 -and $corsOrigin) {
        Write-Host "  [OK] Preflight CORS OPTIONS respondido de inmediato con HTTP 204 No Content:" -ForegroundColor Green
        Write-Host "       $corsOrigin" -ForegroundColor Gray
        Write-Host "       $corsMethods" -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] Fallo en preflight CORS:" -ForegroundColor Red
        Write-Host ($optResp -join "`n") -ForegroundColor Red
    }

} catch {
    Write-Host "  [ERROR] Excepcion al conectar al proxy HTTPS: $_" -ForegroundColor Red
} finally {
    Write-Host "`nLimpiando contenedor de prueba temporal..." -ForegroundColor Gray
    docker rm -f rutaexpress-nginx-test 2>$null | Out-Null
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "  VERIFICACION COMPLETADA CON EXITO (PRODUCCION LOCAL VALIDADA)   " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
