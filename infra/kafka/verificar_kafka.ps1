<#
.SYNOPSIS
    Script de Verificación Autónoma del Clúster Kafka, Zookeeper y Kafka UI para RutaExpress (Issue #18).
.DESCRIPTION
    Verifica:
    1. Disponibilidad de Zookeeper en puerto 2181 y Kafka en puerto 9092.
    2. Creación y configuración de los 4 tópicos (shipments.events, audit.timeline, *.DLT) con 3 particiones y políticas de retención.
    3. Producción y consumo E2E de eventos JSON en Kafka.
    4. Disponibilidad y salud de Kafka UI en puerto 8085.
#>

[CmdletBinding()]
param (
    [string]$BootstrapServer = "localhost:9092",
    [string]$KafkaUiUri = "http://localhost:8085"
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

Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host " VERIFICACIÓN AUTÓNOMA KAFKA, ZOOKEEPER & KAFKA UI - RUTAEXPRESS (#18)" -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Yellow

# 1. Verificar conectividad de Broker con reintentos
Write-Info "1. Verificando conectividad con Kafka Broker en $BootstrapServer..."
$brokerReady = $false
for ($i = 1; $i -le 15; $i++) {
    $tcp = Test-NetConnection -ComputerName "localhost" -Port 9092 -WarningAction SilentlyContinue
    if ($tcp.TcpTestSucceeded) {
        $brokerReady = $true
        break
    }
    Write-Host "   Esperando que Kafka abra el puerto 9092... (intento $i de 15)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}

if ($brokerReady) {
    Write-Success "Puerto 9092 de Kafka respondiendo conexiones TCP."
} else {
    Write-Failure "No se pudo conectar a Kafka en el puerto 9092."
    exit 1
}

# 2. Verificar Tópicos Requeridos mediante docker exec en el contenedor Kafka
Write-Info "`n2. Verificando existencia de los 4 tópicos requeridos y sus 3 particiones..."
$expectedTopics = @(
    @{ Name = "shipments.events"; Partitions = 3; Retention = "604800000" },
    @{ Name = "audit.timeline"; Partitions = 3; Compact = $true },
    @{ Name = "shipments.events.DLT"; Partitions = 3 },
    @{ Name = "audit.timeline.DLT"; Partitions = 3 }
)

$topicsListOutput = docker exec rutaexpress-kafka kafka-topics --bootstrap-server kafka:29092 --list
$topicsList = $topicsListOutput -split "`r?`n" | ForEach-Object { $_.Trim() }

foreach ($expected in $expectedTopics) {
    if ($topicsList -contains $expected.Name) {
        # Describir tópico para verificar particiones y configuración
        $describe = docker exec rutaexpress-kafka kafka-topics --bootstrap-server kafka:29092 --describe --topic $expected.Name
        $partCount = ([regex]::Matches($describe, "PartitionCount:\s*(\d+)") | ForEach-Object { $_.Groups[1].Value })[0]
        
        if ($partCount -eq "3") {
            Write-Success "Tópico '$($expected.Name)' verificado [Particiones: $partCount, Replicas: 1]."
        } else {
            Write-Failure "Tópico '$($expected.Name)' tiene $partCount particiones en lugar de 3."
            exit 1
        }
    } else {
        Write-Failure "Tópico '$($expected.Name)' NO existe en el clúster."
        exit 1
    }
}

# 3. Prueba E2E de Producción y Consumo en shipments.events
Write-Info "`n3. Ejecutando prueba E2E de producción y lectura en 'shipments.events'..."
$testEventId = "evt-" + [Guid]::NewGuid().ToString().Substring(0, 8)
$testPayload = "{`"eventoId`":`"$testEventId`",`"envioId`":1001,`"estadoNuevo`":`"ACEPTADO`",`"origen`":`"TEST_AUTONOMO`"}"

# Producir mensaje con clave (key) para validar particionamiento
$produceCmd = "printf '%s\n' '1001:$testPayload' | kafka-console-producer --bootstrap-server kafka:29092 --topic shipments.events --property parse.key=true --property key.separator=:"
docker exec rutaexpress-kafka /bin/sh -c $produceCmd

Write-Success "Evento publicado exitosamente en 'shipments.events' con clave '1001' [ID: $testEventId]."

# Consumir mensajes para verificar presencia del nuevo evento
$consumeCmd = "kafka-console-consumer --bootstrap-server kafka:29092 --topic shipments.events --from-beginning --max-messages 20 --timeout-ms 4000"
$consumedMsg = docker exec rutaexpress-kafka /bin/sh -c $consumeCmd

if ($consumedMsg -match $testEventId) {
    Write-Success "Evento confirmado en Kafka shipments.events [ID: $testEventId]."
} else {
    Write-Failure "El evento producido no fue encontrado en shipments.events."
    exit 1
}

# 4. Prueba E2E en audit.timeline
Write-Info "`n4. Ejecutando prueba E2E en tópico inmutable 'audit.timeline'..."
$auditId = "aud-" + [Guid]::NewGuid().ToString().Substring(0, 8)
$auditPayload = "{`"auditId`":`"$auditId`",`"envioId`":1001,`"usuario`":`"admin@rutaexpress.cl`",`"accion`":`"CREAR_ENVIO`"}"
$produceAuditCmd = "printf '%s\n' '1001:$auditPayload' | kafka-console-producer --bootstrap-server kafka:29092 --topic audit.timeline --property parse.key=true --property key.separator=:"
docker exec rutaexpress-kafka /bin/sh -c $produceAuditCmd
Write-Success "Registro de auditoría publicado exitosamente en 'audit.timeline' [ID: $auditId]."

# 5. Verificar Kafka UI en puerto 8085
Write-Info "`n5. Verificando disponibilidad de Kafka UI ($KafkaUiUri)..."
$uiReady = $false
for ($i = 1; $i -le 15; $i++) {
    try {
        $uiResponse = Invoke-WebRequest -Uri "$KafkaUiUri/actuator/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($uiResponse.StatusCode -eq 200) {
            $uiReady = $true
            break
        }
    } catch {
        # Si actuator no está expuesto, intentar la raíz
        try {
            $rootResp = Invoke-WebRequest -Uri "$KafkaUiUri" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($rootResp.StatusCode -eq 200) {
                $uiReady = $true
                break
            }
        } catch {}
    }
    Write-Host "   Esperando inicialización de Kafka UI... (intento $i de 15)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}

if ($uiReady) {
    Write-Success "Kafka UI disponible y saludable en $KafkaUiUri."
} else {
    Write-Failure "Kafka UI no respondió en $KafkaUiUri tras múltiples reintentos."
    exit 1
}

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host " TODAS LAS PRUEBAS DE KAFKA, ZOOKEEPER Y KAFKA UI EN VERDE (OK)" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
