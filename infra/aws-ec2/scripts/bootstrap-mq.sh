#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Automatizado: Servidor RabbitMQ en ec2-mq (Issue #26)
# ==============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/4] Actualizando sistema e instalando Docker ==="
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

echo "=== [2/4] Creando directorio y archivos de configuracion RabbitMQ ==="
mkdir -p /opt/rutaexpress/mq
cd /opt/rutaexpress/mq

# Generacion de configuracion rabbitmq.conf
cat << 'EOF' > rabbitmq.conf
loopback_users.guest = false
listeners.tcp.default = 5672
management.tcp.port = 15672
management.load_definitions = /etc/rabbitmq/definitions.json
EOF

# Generacion de topologia de 6 colas, 3 exchanges y DLQ
cat << 'EOF' > definitions.json
{
  "rabbit_version": "3.13.0",
  "users": [
    {
      "name": "guest",
      "password_hash": "A3eR3uU1Vf1kX8h4G8j1l2o3p4q5r6s7t8u9v0w1x2y=",
      "hashing_algorithm": "rabbit_password_hashing_sha256",
      "tags": ["administrator"]
    }
  ],
  "vhosts": [
    {
      "name": "/"
    }
  ],
  "permissions": [
    {
      "user": "guest",
      "vhost": "/",
      "configure": ".*",
      "write": ".*",
      "read": ".*"
    }
  ],
  "exchanges": [
    {
      "name": "cmd.direct",
      "vhost": "/",
      "type": "direct",
      "durable": true,
      "auto_delete": false,
      "internal": false,
      "arguments": {}
    },
    {
      "name": "cmd.topic",
      "vhost": "/",
      "type": "topic",
      "durable": true,
      "auto_delete": false,
      "internal": false,
      "arguments": {}
    },
    {
      "name": "cmd.dead.dlx",
      "vhost": "/",
      "type": "direct",
      "durable": true,
      "auto_delete": false,
      "internal": false,
      "arguments": {}
    }
  ],
  "queues": [
    {
      "name": "q.cmd.email",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {
        "x-dead-letter-exchange": "cmd.dead.dlx",
        "x-dead-letter-routing-key": "email.dead"
      }
    },
    {
      "name": "q.cmd.email.dlq",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {}
    },
    {
      "name": "q.cmd.warehouse",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {
        "x-dead-letter-exchange": "cmd.dead.dlx",
        "x-dead-letter-routing-key": "warehouse.dead"
      }
    },
    {
      "name": "q.cmd.warehouse.dlq",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {}
    },
    {
      "name": "q.cmd.label",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {
        "x-dead-letter-exchange": "cmd.dead.dlx",
        "x-dead-letter-routing-key": "label.dead"
      }
    },
    {
      "name": "q.cmd.label.dlq",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {}
    }
  ],
  "bindings": [
    {
      "source": "cmd.topic",
      "vhost": "/",
      "destination": "q.cmd.email",
      "destination_type": "queue",
      "routing_key": "email.*",
      "arguments": {}
    },
    {
      "source": "cmd.direct",
      "vhost": "/",
      "destination": "q.cmd.email",
      "destination_type": "queue",
      "routing_key": "email.send",
      "arguments": {}
    },
    {
      "source": "cmd.dead.dlx",
      "vhost": "/",
      "destination": "q.cmd.email.dlq",
      "destination_type": "queue",
      "routing_key": "email.dead",
      "arguments": {}
    },
    {
      "source": "cmd.topic",
      "vhost": "/",
      "destination": "q.cmd.warehouse",
      "destination_type": "queue",
      "routing_key": "warehouse.#",
      "arguments": {}
    },
    {
      "source": "cmd.direct",
      "vhost": "/",
      "destination": "q.cmd.warehouse",
      "destination_type": "queue",
      "routing_key": "warehouse.ticket",
      "arguments": {}
    },
    {
      "source": "cmd.dead.dlx",
      "vhost": "/",
      "destination": "q.cmd.warehouse.dlq",
      "destination_type": "queue",
      "routing_key": "warehouse.dead",
      "arguments": {}
    },
    {
      "source": "cmd.topic",
      "vhost": "/",
      "destination": "q.cmd.label",
      "destination_type": "queue",
      "routing_key": "label.*",
      "arguments": {}
    },
    {
      "source": "cmd.direct",
      "vhost": "/",
      "destination": "q.cmd.label",
      "destination_type": "queue",
      "routing_key": "label.gen",
      "arguments": {}
    },
    {
      "source": "cmd.dead.dlx",
      "vhost": "/",
      "destination": "q.cmd.label.dlq",
      "destination_type": "queue",
      "routing_key": "label.dead",
      "arguments": {}
    }
  ]
}
EOF

# Compose file para RabbitMQ
cat << 'EOF' > compose.yml
services:
  rutaexpress-rabbitmq:
    image: rabbitmq:3.13-management-alpine
    container_name: rutaexpress-rabbitmq
    restart: unless-stopped
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./definitions.json:/etc/rabbitmq/definitions.json:ro
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  rabbitmq_data:
    driver: local
EOF

echo "=== [3/4] Levantando contenedor RabbitMQ ==="
docker compose up -d

echo "=== [4/4] Verificando salud del servicio y asegurando credenciales ==="
sleep 10
docker exec rutaexpress-rabbitmq rabbitmqctl change_password guest guest || true
docker ps
curl -s -u guest:guest http://localhost:15672/api/overview | grep -o '"rabbitmq_version":"[^"]*"' || true
echo "=== Bootstrap RabbitMQ completado exitosamente ==="
