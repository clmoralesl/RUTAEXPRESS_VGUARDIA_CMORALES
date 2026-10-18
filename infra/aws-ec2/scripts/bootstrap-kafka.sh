#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Automatizado: Cluster Kafka y Zookeeper en ec2-kafka (Issue #26)
# ==============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/5] Actualizando sistema e instalando Docker ==="
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

echo "=== [2/5] Obteniendo IP privada local desde AWS Instance Metadata (IMDSv2) ==="
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
if [ -n "$IMDS_TOKEN" ]; then
    PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
else
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
fi

echo "IP Privada de Kafka: $PRIVATE_IP"

echo "=== [3/5] Creando directorio y compose.yml de Kafka ==="
mkdir -p /opt/rutaexpress/kafka
cd /opt/rutaexpress/kafka

cat << EOF > compose.yml
services:
  rutaexpress-zookeeper:
    image: confluentinc/cp-zookeeper:7.6.1
    container_name: rutaexpress-zookeeper
    restart: unless-stopped
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    volumes:
      - zookeeper_data:/var/lib/zookeeper/data
      - zookeeper_log:/var/lib/zookeeper/log

  rutaexpress-kafka:
    image: confluentinc/cp-kafka:7.6.1
    container_name: rutaexpress-kafka
    restart: unless-stopped
    depends_on:
      - rutaexpress-zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: rutaexpress-zookeeper:2181
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_INTERNAL:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://$PRIVATE_IP:9092,PLAINTEXT_INTERNAL://rutaexpress-kafka:29092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,PLAINTEXT_INTERNAL://0.0.0.0:29092
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT_INTERNAL
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
    volumes:
      - kafka_data:/var/lib/kafka/data

  rutaexpress-kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: rutaexpress-kafka-ui
    restart: unless-stopped
    depends_on:
      - rutaexpress-kafka
    ports:
      - "8085:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: rutaexpress-aws-cluster
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: rutaexpress-kafka:29092
      KAFKA_CLUSTERS_0_ZOOKEEPER: rutaexpress-zookeeper:2181

volumes:
  zookeeper_data:
  zookeeper_log:
  kafka_data:
EOF

echo "=== [4/5] Levantando servicios Kafka, Zookeeper y Kafka UI ==="
docker compose up -d

echo "=== [5/5] Inicializando topicos con retencion y particiones ==="
sleep 25
docker exec rutaexpress-kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic shipments.events --partitions 3 --replication-factor 1 || true

docker exec rutaexpress-kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic audit.timeline --partitions 3 --replication-factor 1 || true

docker exec rutaexpress-kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic shipments.events.DLT --partitions 3 --replication-factor 1 || true

docker exec rutaexpress-kafka kafka-topics --bootstrap-server localhost:9092 \
    --list || true

echo "=== Bootstrap Kafka completado exitosamente ==="
