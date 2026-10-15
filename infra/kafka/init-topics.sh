#!/bin/sh
# =====================================================================
# Script de Inicialización de Tópicos Kafka - RutaExpress (Issue #18)
# =====================================================================

set -e

BOOTSTRAP_SERVER=${BOOTSTRAP_SERVER:-"kafka:29092"}

echo "[INFO] Esperando a que el broker Kafka ($BOOTSTRAP_SERVER) este listo..."
until kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" --list > /dev/null 2>&1; do
  echo "[INFO] Kafka no responde aun. Reintentando en 3 segundos..."
  sleep 3
done

echo "[OK] Broker Kafka disponible. Procediendo a crear topicos requeridos..."

# 1. shipments.events: Topico troncal de eventos de ciclo de vida (3 particiones, 7 dias de retencion)
echo "[INFO] Creando topico 'shipments.events'..."
kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic shipments.events \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=604800000

# 2. audit.timeline: Topico especializado de auditoria inmutable (3 particiones, compact,delete)
echo "[INFO] Creando topico 'audit.timeline'..."
kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic audit.timeline \
  --partitions 3 \
  --replication-factor 1 \
  --config cleanup.policy=compact,delete \
  --config retention.ms=2592000000

# 3. shipments.events.DLT: Dead Letter Topic para eventos de envios
echo "[INFO] Creando topico 'shipments.events.DLT'..."
kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic shipments.events.DLT \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=1209600000

# 4. audit.timeline.DLT: Dead Letter Topic para eventos de auditoria
echo "[INFO] Creando topico 'audit.timeline.DLT'..."
kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic audit.timeline.DLT \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=1209600000

echo "[OK] Topicos creados exitosamente en Kafka:"
kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" --list
