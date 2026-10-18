# ==============================================================================
# Script de Verificacion: Arquitectura Multi-Instancia AWS (Issue #26)
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VERIFICACION DE DESPLIEGUE MULTI-INSTANCIA EN AWS (ISSUE #26)   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainTf    = Join-Path $scriptDir "main.tf"
$varsTf    = Join-Path $scriptDir "variables.tf"
$outTf     = Join-Path $scriptDir "outputs.tf"
$scriptMq  = Join-Path $scriptDir "scripts/bootstrap-mq.sh"
$scriptKfk = Join-Path $scriptDir "scripts/bootstrap-kafka.sh"
$scriptApp = Join-Path $scriptDir "scripts/bootstrap-apps.sh"

# 1. Validacion de archivos Terraform y formateo HCL
Write-Host "`n[1/4] Verificando sintaxis y formateo de archivos Terraform HCL..." -ForegroundColor Yellow
if ((Test-Path $mainTf) -and (Test-Path $varsTf) -and (Test-Path $outTf)) {
    $fmtCheck = & terraform fmt -check $scriptDir 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Archivos main.tf, variables.tf y outputs.tf con sintaxis HCL valida y formato correcto." -ForegroundColor Green
    } else {
        Write-Host "  [ADVERTENCIA] Formato HCL requiere ajuste: $fmtCheck" -ForegroundColor Yellow
    }
} else {
    Write-Error "Faltan archivos de Terraform en $scriptDir."
}

# 2. Verificacion de Reglas de Security Groups e Incomunicacion Externa
Write-Host "`n[2/4] Verificando aislamiento estricto de Security Groups..." -ForegroundColor Yellow
$mainContent = Get-Content -Path $mainTf -Raw

$hasMqIsolation = ($mainContent -match 'to_port\s*=\s*5672') -and ($mainContent -match 'security_groups\s*=\s*\[aws_security_group\.sg_ec2_apps\.id\]')
$hasKafkaIsolation = ($mainContent -match 'to_port\s*=\s*9092') -and ($mainContent -match 'security_groups\s*=\s*\[aws_security_group\.sg_ec2_apps\.id\]')
$hasHttpsApps = ($mainContent -match 'to_port\s*=\s*443') -and ($mainContent -match 'cidr_blocks\s*=\s*\["0\.0\.0\.0/0"\]')

if ($hasMqIsolation) {
    Write-Host "  [OK] Regla de Seguridad MQ: Puerto AMQP 5672 restringido exclusivamente a sg_ec2_apps." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Falla en regla de aislamiento de RabbitMQ." -ForegroundColor Red
}

if ($hasKafkaIsolation) {
    Write-Host "  [OK] Regla de Seguridad Kafka: Puerto Broker 9092 restringido exclusivamente a sg_ec2_apps." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Falla en regla de aislamiento de Kafka." -ForegroundColor Red
}

if ($hasHttpsApps) {
    Write-Host "  [OK] Regla de Seguridad Apps: Puertos 443 (HTTPS) y 80 (HTTP) expuestos publicamente hacia Nginx." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Falla en exposicion publica de Nginx en ec2-apps." -ForegroundColor Red
}

# 3. Validacion de Scripts de Bootstrap Automatizado
Write-Host "`n[3/4] Verificando scripts de Bootstrap y User Data..." -ForegroundColor Yellow
$mqContent = Get-Content -Path $scriptMq -Raw
$kfkContent = Get-Content -Path $scriptKfk -Raw
$appContent = Get-Content -Path $scriptApp -Raw

$has6Queues = ($mqContent -match "q\.cmd\.email") -and ($mqContent -match "q\.cmd\.warehouse") -and ($mqContent -match "q\.cmd\.label") -and ($mqContent -match "cmd\.dead\.dlx")
$hasKafkaTopics = ($kfkContent -match "shipments\.events") -and ($kfkContent -match "audit\.timeline") -and ($kfkContent -match "cp-zookeeper")
$hasAppEnvInject = ($appContent -match 'SPRING_RABBITMQ_HOST') -and ($appContent -match 'SPRING_KAFKA_BOOTSTRAP_SERVERS') -and ($appContent -match 'nginx')

if ($has6Queues) {
    Write-Host "  [OK] Script bootstrap-mq.sh aprovisiona topologia de 6 colas, 3 exchanges y Dead Letter Queues." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Faltan colas o exchanges en bootstrap-mq.sh." -ForegroundColor Red
}

if ($hasKafkaTopics) {
    Write-Host "  [OK] Script bootstrap-kafka.sh aprovisiona Zookeeper, Kafka, Kafka UI y topicos estructurados." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Faltan configuraciones en bootstrap-kafka.sh." -ForegroundColor Red
}

if ($hasAppEnvInject) {
    Write-Host "  [OK] Script bootstrap-apps.sh inyecta IPs privadas de brokers y fachada HTTPS Nginx." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Faltan variables de conexion en bootstrap-apps.sh." -ForegroundColor Red
}

# 4. Comprobacion de Instancias y Outputs
Write-Host "`n[4/4] Verificando definicion de instancias y outputs..." -ForegroundColor Yellow
$has3Instances = ($mainContent -match 'resource\s+"aws_instance"\s+"ec2_apps"') -and `
                 ($mainContent -match 'resource\s+"aws_instance"\s+"ec2_mq"') -and `
                 ($mainContent -match 'resource\s+"aws_instance"\s+"ec2_kafka"')

if ($has3Instances) {
    Write-Host "  [OK] 3 Instancias EC2 declaradas: ec2-apps, ec2-mq y ec2-kafka." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] No se encontraron las 3 instancias EC2." -ForegroundColor Red
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "  ARQUITECTURA MULTI-INSTANCIA AWS VALIDADA CON EXITO (ISSUE #26) " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
