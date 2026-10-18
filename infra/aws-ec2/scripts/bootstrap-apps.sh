#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Automatizado: Frontend Nginx HTTPS, BFF y Microservicios en ec2-apps
# ==============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

RABBITMQ_HOST="${RABBITMQ_PRIVATE_IP}"
KAFKA_SERVERS="${KAFKA_PRIVATE_IP}:9092"

echo "=== [1/5] Actualizando sistema e instalando Docker ==="
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release openssl git

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

echo "=== [2/5] Configurando estructura de directorios y certificados SSL ==="
mkdir -p /opt/rutaexpress/apps/nginx/certs
cd /opt/rutaexpress/apps

# Generacion de certificados SSL autofirmados con SAN
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/rutaexpress/apps/nginx/certs/localhost.key \
    -out /opt/rutaexpress/apps/nginx/certs/localhost.crt \
    -subj "/C=CL/ST=Region Metropolitana/L=Santiago/O=RutaExpress SaaS/OU=Cloud/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "=== [3/5] Generando nginx.conf con HTTPS y contexto seguro MSAL ==="
cat << 'EOF' > /opt/rutaexpress/apps/nginx/nginx.conf
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server_tokens off;

    # DNS de Docker
    resolver 127.0.0.11 valid=30s ipv6=off;

    # Redireccion forzosa HTTP a HTTPS
    server {
        listen 80;
        server_name _;
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # Fachada Unificada HTTPS Same-Origin
    server {
        listen 443 ssl;
        http2 on;
        server_name _;

        ssl_certificate /etc/nginx/certs/localhost.crt;
        ssl_certificate_key /etc/nginx/certs/localhost.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;

        # API y BFF
        location /api/ {
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '$http_origin' always;
                add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, PATCH, DELETE, OPTIONS' always;
                add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, Origin, X-Requested-With' always;
                add_header 'Access-Control-Allow-Credentials' 'true' always;
                add_header 'Access-Control-Max-Age' 86400;
                return 204;
            }

            set $upstream_bff http://ms-rutaexpress-bff:8080;
            proxy_pass $upstream_bff$request_uri;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }

        # Frontend SPA
        location / {
            set $upstream_frontend http://rutaexpress-frontend:80;
            proxy_pass $upstream_frontend$request_uri;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Proto https;
        }

        location /salud-proxy {
            default_type application/json;
            return 200 '{"estado":"UP","servicio":"rutaexpress-nginx-proxy","nodo":"aws-ec2-apps"}';
        }
    }
}
EOF

echo "=== [4/5] Escribiendo variables de entorno de conexion hacia ec2-mq y ec2-kafka ==="
cat << EOF > /opt/rutaexpress/apps/.env
SPRING_PROFILES_ACTIVE=prod
SPRING_RABBITMQ_HOST=$RABBITMQ_HOST
SPRING_RABBITMQ_PORT=5672
SPRING_RABBITMQ_USERNAME=guest
SPRING_RABBITMQ_PASSWORD=guest
SPRING_KAFKA_BOOTSTRAP_SERVERS=$KAFKA_SERVERS
JWK_SET_URI=https://login.microsoftonline.com/common/discovery/keys
RUTAEXPRESS_CATALOGO_URL=http://ms-rutaexpress-catalogo:8082
RUTAEXPRESS_AUDITORIA_URL=http://ms-rutaexpress-auditoria:8084
RUTAEXPRESS_REPORTES_URL=http://ms-rutaexpress-reportes:8086
RUTAEXPRESS_ENVIOS_URL=http://ms-rutaexpress-envios:8081
EOF

echo "=== [5/5] Generando docker-compose.yml para las aplicaciones ==="
cat << 'EOF' > /opt/rutaexpress/apps/docker-compose.yml
services:
  rutaexpress-nginx-proxy:
    image: nginx:1.27-alpine
    container_name: rutaexpress-nginx-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - ms-rutaexpress-bff
      - rutaexpress-frontend
    networks:
      - rutaexpress-network

  ms-rutaexpress-bff:
    image: eclipse-temurin:17-jre-alpine
    container_name: ms-rutaexpress-bff
    restart: unless-stopped
    env_file: .env
    ports:
      - "8080:8080"
    networks:
      - rutaexpress-network
    command: ["sh", "-c", "echo 'BFF Container Ready' && sleep infinity"]

  rutaexpress-frontend:
    image: nginx:1.27-alpine
    container_name: rutaexpress-frontend
    restart: unless-stopped
    ports:
      - "4200:80"
    networks:
      - rutaexpress-network

networks:
  rutaexpress-network:
    driver: bridge
EOF

docker compose up -d
echo "=== Bootstrap ec2-apps completado exitosamente ==="
