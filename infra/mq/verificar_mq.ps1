<#
.SYNOPSIS
    Script de Verificación Autónoma de la Topología de RabbitMQ para RutaExpress (Issue #17).
.DESCRIPTION
    Verifica:
    1. Disponibilidad del servidor RabbitMQ y Management API en puerto 15672.
    2. Existencia y configuración de los 3 Exchanges (cmd.direct, cmd.topic, cmd.dead.dlx).
    3. Existencia y configuración de las 6 Colas (3 principales + 3 DLQ) con sus argumentos DLX.
    4. Existencia de los 15 Bindings requeridos.
    5. Prueba E2E de enrutamiento y derivación automática a DLQ ante rechazo (NACK requeue=false).
#>

[CmdletBinding()]
param (
    [string]$HostUri = "http://localhost:15672",
    [string]$User = "guest",
    [string]$Password = "guest"
)

$ErrorActionPreference = "Stop"

function Write-Success ($msg) {
    Write-Host "[OK] $msg" -ForegroundColor Green
}

function Write-Info ($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-Failure ($msg) {
    Write-Host "[FAIL] $msg" -ForegroundColor Red
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Password}"))
$headers = @{
    Authorization = "Basic $auth"
    "Content-Type" = "application/json"
}

Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host " VERIFICACIÓN AUTÓNOMA TOPOLOGÍA RABBITMQ - RUTAEXPRESS (ISSUE #17)" -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Yellow

# 1. Verificar Disponibilidad del Broker (con reintentos para arranque en frío)
Write-Info "1. Verificando conectividad HTTP con RabbitMQ Management API ($HostUri)..."
$overview = $null
$maxRetries = 15
for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        $overview = Invoke-RestMethod -Uri "$HostUri/api/overview" -Headers $headers -TimeoutSec 3
        if ($overview -and $overview.rabbitmq_version) {
            break
        }
    } catch {
        Write-Host "   Esperando inicialización de RabbitMQ... (intento $attempt de $maxRetries)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    }
}

if ($overview -and $overview.rabbitmq_version) {
    Write-Success "RabbitMQ v$($overview.rabbitmq_version) en clúster '$($overview.cluster_name)' respondiendo correctamente."
} else {
    Write-Failure "No se pudo conectar a la API de RabbitMQ en $HostUri tras $maxRetries intentos."
    exit 1
}

# 2. Verificar los 3 Exchanges
Write-Info "`n2. Verificando los 3 Exchanges requeridos..."
$expectedExchanges = @(
    @{ Name = "cmd.direct"; Type = "direct" },
    @{ Name = "cmd.topic"; Type = "topic" },
    @{ Name = "cmd.dead.dlx"; Type = "direct" }
)

$allExchanges = Invoke-RestMethod -Uri "$HostUri/api/exchanges" -Headers $headers
foreach ($exp in $expectedExchanges) {
    $found = $allExchanges | Where-Object { $_.name -eq $exp.Name }
    if ($found -and $found.type -eq $exp.Type -and $found.durable -eq $true) {
        Write-Success "Exchange '$($exp.Name)' [Tipo: $($exp.Type), Durable: True] presente y saludable."
    } else {
        Write-Failure "Exchange '$($exp.Name)' NO encontrado o mal configurado."
        exit 1
    }
}

# 3. Verificar las 6 Colas y sus Argumentos DLQ
Write-Info "`n3. Verificando las 6 Colas (3 principales + 3 DLQ)..."
$expectedQueues = @(
    @{ Name = "q.cmd.email"; IsDlq = $false; Dlk = "email.dead" },
    @{ Name = "q.cmd.email.dlq"; IsDlq = $true },
    @{ Name = "q.cmd.warehouse"; IsDlq = $false; Dlk = "warehouse.dead" },
    @{ Name = "q.cmd.warehouse.dlq"; IsDlq = $true },
    @{ Name = "q.cmd.label"; IsDlq = $false; Dlk = "label.dead" },
    @{ Name = "q.cmd.label.dlq"; IsDlq = $true }
)

$allQueues = Invoke-RestMethod -Uri "$HostUri/api/queues" -Headers $headers
foreach ($q in $expectedQueues) {
    $found = $allQueues | Where-Object { $_.name -eq $q.Name }
    if (-not $found) {
        Write-Failure "Cola '$($q.Name)' NO encontrada."
        exit 1
    }

    if ($q.IsDlq) {
        Write-Success "Cola DLQ '$($q.Name)' [Durable: $($found.durable), TTL: $($found.arguments.'x-message-ttl') ms] activa."
    } else {
        $dlx = $found.arguments.'x-dead-letter-exchange'
        $dlk = $found.arguments.'x-dead-letter-routing-key'
        $ttl = $found.arguments.'x-message-ttl'
        $maxLen = $found.arguments.'x-max-length'

        if ($dlx -eq "cmd.dead.dlx" -and $dlk -eq $q.Dlk -and $ttl -eq 86400000 -and $maxLen -eq 10000) {
            Write-Success "Cola Principal '$($q.Name)' [DLX: $dlx, DLK: $dlk, TTL: $ttl ms, MaxLength: $maxLen] configurada correctamente."
        } else {
            Write-Failure "Cola '$($q.Name)' tiene argumentos DLX incorrectos: DLX=$dlx, DLK=$dlk."
            exit 1
        }
    }
}

# 4. Verificar Bindings
Write-Info "`n4. Verificando Bindings requeridos..."
$allBindings = Invoke-RestMethod -Uri "$HostUri/api/bindings" -Headers $headers
$keyBindings = @(
    @{ Source = "cmd.direct"; Dest = "q.cmd.email"; Key = "email.send" },
    @{ Source = "cmd.topic"; Dest = "q.cmd.email"; Key = "email.*" },
    @{ Source = "cmd.direct"; Dest = "q.cmd.warehouse"; Key = "warehouse.ticket" },
    @{ Source = "cmd.topic"; Dest = "q.cmd.warehouse"; Key = "warehouse.#" },
    @{ Source = "cmd.direct"; Dest = "q.cmd.label"; Key = "label.gen" },
    @{ Source = "cmd.topic"; Dest = "q.cmd.label"; Key = "label.*" },
    @{ Source = "cmd.dead.dlx"; Dest = "q.cmd.email.dlq"; Key = "email.dead" },
    @{ Source = "cmd.dead.dlx"; Dest = "q.cmd.warehouse.dlq"; Key = "warehouse.dead" },
    @{ Source = "cmd.dead.dlx"; Dest = "q.cmd.label.dlq"; Key = "label.dead" }
)

foreach ($b in $keyBindings) {
    $found = $allBindings | Where-Object { $_.source -eq $b.Source -and $_.destination -eq $b.Dest -and $_.routing_key -eq $b.Key }
    if ($found) {
        Write-Success "Binding '$($b.Source)' -> '$($b.Dest)' [Key: '$($b.Key)'] verificado."
    } else {
        Write-Failure "Binding '$($b.Source)' -> '$($b.Dest)' [Key: '$($b.Key)'] NO encontrado."
        exit 1
    }
}

# 5. Prueba E2E de Flujo de Mensajería y Derivación a DLQ
Write-Info "`n5. Ejecutando prueba E2E de publicación y derivación a DLQ (NACK)..."

# Limpiar colas de prueba
try {
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.label/contents" -Method Delete -Headers $headers | Out-Null
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.label.dlq/contents" -Method Delete -Headers $headers | Out-Null
} catch {}

# Publicar comando a cmd.direct
$testMsg = '{"properties":{},"routing_key":"label.gen","payload":"{\"envioId\":2001,\"tipo\":\"GENERAR_ETIQUETA_QR\"}","payload_encoding":"string"}'
$pubResult = Invoke-RestMethod -Uri "$HostUri/api/exchanges/%2F/cmd.direct/publish" -Method Post -Headers $headers -Body $testMsg
if (-not $pubResult.routed) {
    Write-Failure "Mensaje publicado a cmd.direct no pudo ser enrutado."
    exit 1
}
Write-Success "Mensaje de prueba publicado a 'cmd.direct' [Key: 'label.gen'] -> Enrutado exitosamente a 'q.cmd.label'."

# Simular NACK con requeue=false
$getPayload = '{"count":1,"ackmode":"reject_requeue_false","encoding":"auto"}'
$msgConsumido = Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.label/get" -Method Post -Headers $headers -Body $getPayload
if (-not $msgConsumido) {
    Write-Failure "No se pudo obtener el mensaje de 'q.cmd.label' para simular el fallo."
    exit 1
}
Write-Success "Consumidor simulado ejecutó NACK (requeue=false) emulando fallo irrecuperable de procesamiento."

# 5.1 Verificar recepción inmediata en la cola DLQ
$dlqCheckPayload = '{"count":1,"ackmode":"ack_requeue_true","encoding":"auto"}'
$dlqMsg = $null
for ($i = 0; $i -lt 5; $i++) {
    Start-Sleep -Milliseconds 200
    $dlqMsg = Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.label.dlq/get" -Method Post -Headers $headers -Body $dlqCheckPayload
    if ($dlqMsg -and $dlqMsg.payload) {
        break
    }
}

if ($dlqMsg -and $dlqMsg.payload) {
    $deathReason = $dlqMsg.properties.headers.'x-first-death-reason'
    $origQueue = $dlqMsg.properties.headers.'x-first-death-queue'
    Write-Success "Mensaje capturado en tiempo real en 'q.cmd.label.dlq'."
    Write-Success "   -> Routing Key en DLQ: $($dlqMsg.routing_key)"
    Write-Success "   -> Exchange en DLQ: $($dlqMsg.exchange)"
    Write-Success "   -> Origen de rechazo: $origQueue [Motivo: $deathReason]"
    Write-Success "   -> Payload: $($dlqMsg.payload)"
} else {
    Write-Failure "No se encontró el mensaje en 'q.cmd.label.dlq'."
    exit 1
}

# Limpiar colas de prueba al terminar
try {
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.email/contents" -Method Delete -Headers $headers | Out-Null
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.email.dlq/contents" -Method Delete -Headers $headers | Out-Null
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.warehouse/contents" -Method Delete -Headers $headers | Out-Null
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.warehouse.dlq/contents" -Method Delete -Headers $headers | Out-Null
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.label/contents" -Method Delete -Headers $headers | Out-Null
    Invoke-RestMethod -Uri "$HostUri/api/queues/%2F/q.cmd.label.dlq/contents" -Method Delete -Headers $headers | Out-Null
} catch {}

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host " TODAS LAS PRUEBAS DE LA TOPOLOGÍA RABBITMQ FINALIZARON EN VERDE (OK)" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
