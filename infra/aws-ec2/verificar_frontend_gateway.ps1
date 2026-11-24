<#
.SYNOPSIS
  Verifica la integracion del frontend con el API Gateway en tiempo de ejecucion (issue #125).

.DESCRIPTION
  Realiza comprobaciones en entorno local (-Local) o contra un despliegue remoto (-Borde y -Gateway).
  Usa curl.exe -sk. Nunca envia ni registra tokens de autorizacion.

  Codigos de salida:
    0 - VERDE (todas las comprobaciones exitosas)
    1 - ROJO (al menos una comprobacion fallida)
    2 - BLOQUEADO (Docker no disponible en modo -Local)

.EXAMPLE
  .\infra\aws-ec2\verificar_frontend_gateway.ps1 -Local
  .\infra\aws-ec2\verificar_frontend_gateway.ps1 -Borde "https://10.0.0.1" -Gateway "https://abc123.execute-api.us-east-1.amazonaws.com"
#>
[CmdletBinding(DefaultParameterSetName = 'Remoto')]
param(
    [Parameter(ParameterSetName = 'Remoto', Mandatory = $true)]
    [string]$Borde,

    [Parameter(ParameterSetName = 'Remoto', Mandatory = $true)]
    [string]$Gateway,

    [Parameter(ParameterSetName = 'Local', Mandatory = $true)]
    [switch]$Local
)

$ErrorActionPreference = 'Continue'

if ($Local) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  VERIFICACION LOCAL: IMAGEN FRONTEND Y SCRIPT DE CONFIGURACION   " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan

    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Host "[BLOQUEADO] Docker no esta instalado o no se encuentra en el PATH." -ForegroundColor Yellow
        exit 2
    }

    $dockerInfo = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[BLOQUEADO] El daemon de Docker no esta en ejecucion o no responde." -ForegroundColor Yellow
        exit 2
    }

    $raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $frontendDir = Join-Path $raiz 'rutaexpress-frontend'
    $tag = "rutaexpress-frontend:test-issue-125"

    Write-Host "`n[1/4] Construyendo imagen de prueba $tag..." -ForegroundColor Yellow
    & docker build -t $tag $frontendDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ROJO] Falla al construir la imagen de prueba del frontend." -ForegroundColor Red
        exit 1
    }

    $fallas = 0

    try {
        Write-Host "`n[2/4] Caso (a): RUTAEXPRESS_API_URL con barra final normalizada..." -ForegroundColor Yellow
        $outA = & docker run --rm -e RUTAEXPRESS_API_URL="https://ficticio.execute-api.us-east-1.amazonaws.com/" $tag sh -c "/docker-entrypoint.d/40-rutaexpress-config.sh && cat /usr/share/nginx/html/config.js" 2>&1
        $codeA = $LASTEXITCODE
        if ($codeA -eq 0 -and ($outA -match 'apiUrl: "https://ficticio\.execute-api\.us-east-1\.amazonaws\.com"')) {
            Write-Host "  [OK] URL normalizada sin barra final en config.js." -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Caso (a) fallido. Codigo: $codeA, Salida: $outA" -ForegroundColor Red
            $fallas++
        }

        Write-Host "`n[3/4] Caso (b): Sin variable RUTAEXPRESS_API_URL (mismo origen)..." -ForegroundColor Yellow
        $outB = & docker run --rm $tag sh -c "/docker-entrypoint.d/40-rutaexpress-config.sh && cat /usr/share/nginx/html/config.js" 2>&1
        $codeB = $LASTEXITCODE
        if ($codeB -eq 0 -and ($outB -match 'apiUrl: ""')) {
            Write-Host "  [OK] config.js emitido con apiUrl: `"`" (mismo origen)." -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Caso (b) fallido. Codigo: $codeB, Salida: $outB" -ForegroundColor Red
            $fallas++
        }

        Write-Host "`n[4/4] Caso (c): Valores invalidos (C4, C6)..." -ForegroundColor Yellow
        $invalidas = @(
            'https://a.example.test/ruta',
            'javascript:alert(1)',
            "https://gw.example.test`nalert(1)"
        )
        foreach ($inv in $invalidas) {
            $outC = & docker run --rm -e RUTAEXPRESS_API_URL="$inv" $tag sh -c "/docker-entrypoint.d/40-rutaexpress-config.sh" 2>&1
            $codeC = $LASTEXITCODE
            if ($codeC -ne 0) {
                Write-Host "  [OK] Valor invalido '$inv' rechazado (codigo $codeC)." -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] Valor invalido '$inv' no fue rechazado (codigo 0)." -ForegroundColor Red
                $fallas++
            }
        }
    }
    finally {
        Write-Host "`nLimpiando imagen de prueba $tag..." -ForegroundColor Yellow
        & docker rmi $tag 2>&1 | Out-Null
    }

    if ($fallas -gt 0) {
        Write-Host "`n[ROJO] Verificacion local finalizada con $fallas fallas." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n[VERDE] Todas las comprobaciones locales pasaron exitosamente." -ForegroundColor Green
        exit 0
    }
}

# Modo Remoto
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VERIFICACION REMOTA: FRONTEND Y API GATEWAY (ISSUE #125)       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$BordeNorm = $Borde.TrimEnd('/')
$GatewayNorm = $Gateway.TrimEnd('/')
$fallas = 0

# Comprobacion 1: GET {Borde}/config.js
Write-Host "`n[1/4] GET $BordeNorm/config.js..." -ForegroundColor Yellow
$resp1 = & curl.exe -sk -i "$BordeNorm/config.js" 2>&1
$status1 = ($resp1 | Select-String -Pattern 'HTTP/[0-9.]+\s+(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -Last 1
$hasNoStore = [bool]($resp1 -match 'Cache-Control:.*no-store')
$hasApiUrl = [bool]($resp1 -match "apiUrl:\s*`"$GatewayNorm`"")

if ($status1 -eq '200' -and $hasNoStore -and $hasApiUrl) {
    Write-Host "  [OK] 200 OK, Cache-Control: no-store presente y apiUrl coincide con el Gateway." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Falla en /config.js. Estado=$status1, no-store=$hasNoStore, apiUrlValida=$hasApiUrl" -ForegroundColor Red
    $fallas++
}

# Comprobacion 2: OPTIONS {Gateway}/api/bff/envios (Preflight CORS)
Write-Host "`n[2/4] OPTIONS $GatewayNorm/api/bff/envios (Preflight CORS)..." -ForegroundColor Yellow
$resp2 = & curl.exe -sk -i -X OPTIONS "$GatewayNorm/api/bff/envios" `
    -H "Origin: $BordeNorm" `
    -H "Access-Control-Request-Method: GET" `
    -H "Access-Control-Request-Headers: authorization,content-type" 2>&1
$status2 = ($resp2 | Select-String -Pattern 'HTTP/[0-9.]+\s+(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -Last 1
$allowHeaders = ($resp2 | Select-String -Pattern 'Access-Control-Allow-Headers:\s*(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
$hasAuth = $allowHeaders -match 'authorization'
$hasContentType = $allowHeaders -match 'content-type'

if ($status2 -eq '204' -and $hasAuth -and $hasContentType) {
    Write-Host "  [OK] 204 No Content, Access-Control-Allow-Headers contiene authorization y content-type." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Falla en Preflight. Estado=$status2, authorization=$hasAuth, content-type=$hasContentType" -ForegroundColor Red
    $fallas++
}

# Comprobacion 3: GET {Gateway}/api/bff/envios (Sin token con Origin)
Write-Host "`n[3/4] GET $GatewayNorm/api/bff/envios (Sin token)..." -ForegroundColor Yellow
$resp3 = & curl.exe -sk -i "$GatewayNorm/api/bff/envios" -H "Origin: $BordeNorm" 2>&1
$status3 = ($resp3 | Select-String -Pattern 'HTTP/[0-9.]+\s+(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -Last 1
$hasOrigin3 = [bool]($resp3 -match 'Access-Control-Allow-Origin:')

if ($status3 -eq '401') {
    Write-Host "  [OK] 401 Unauthorized recibido correctamente desde el Gateway." -ForegroundColor Green
    if (-not $hasOrigin3) {
        Write-Host "  [ALERTA C15] Falta Access-Control-Allow-Origin en el 401 del autorizador. El navegador reportara estado 0." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [ERROR] Se esperaba estado 401 pero se recibio: $status3" -ForegroundColor Red
    $fallas++
}

# Comprobacion 4: GET {Gateway}/api/publico/salud (Ruta publica con Origin)
Write-Host "`n[4/4] GET $GatewayNorm/api/publico/salud (Ruta publica)..." -ForegroundColor Yellow
$resp4 = & curl.exe -sk -i "$GatewayNorm/api/publico/salud" -H "Origin: $BordeNorm" 2>&1
$status4 = ($resp4 | Select-String -Pattern 'HTTP/[0-9.]+\s+(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -Last 1
$hasOrigin4 = [bool]($resp4 -match 'Access-Control-Allow-Origin:')

if ($status4 -eq '200' -and $hasOrigin4) {
    Write-Host "  [OK] 200 OK y Access-Control-Allow-Origin presente." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Falla en ruta publica. Estado=$status4, Access-Control-Allow-Origin=$hasOrigin4" -ForegroundColor Red
    $fallas++
}

if ($fallas -gt 0) {
    Write-Host "`n[ROJO] Verificacion remota finalizada con $fallas fallas." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[VERDE] Todas las comprobaciones remotas pasaron exitosamente." -ForegroundColor Green
    exit 0
}
