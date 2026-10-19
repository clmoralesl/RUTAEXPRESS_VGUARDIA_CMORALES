#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Automatizado: Stack Completo en ec2-apps (Issue #26)
# ==============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

RABBITMQ_HOST="${RABBITMQ_PRIVATE_IP}"
KAFKA_SERVERS="${KAFKA_PRIVATE_IP}:9092"

echo "=== [1/6] Actualizando sistema e instalando Docker, Git y OpenSSL ==="
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release openssl git unzip

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

echo "=== [2/6] Preparando espacio de trabajo y clonando repositorios ==="
mkdir -p /opt/rutaexpress
cd /opt/rutaexpress

API_GATEWAY_URL="${API_GATEWAY_URL:-}"

# Clonar repositorios de microservicios y frontend
git clone https://github.com/clmoralesl/RUTAEXPRESS_VGUARDIA_CMORALES.git || (cd RUTAEXPRESS_VGUARDIA_CMORALES && git pull)
git clone https://github.com/clmoralesl/rutaexpress-frontend.git || (cd rutaexpress-frontend && git pull)
git clone https://github.com/clmoralesl/ms-rutaexpress-bff.git || (cd ms-rutaexpress-bff && git pull)
git clone https://github.com/clmoralesl/ms-rutaexpress-envios.git || (cd ms-rutaexpress-envios && git pull)
git clone https://github.com/clmoralesl/ms-rutaexpress-catalogo.git || (cd ms-rutaexpress-catalogo && git pull)
git clone https://github.com/clmoralesl/ms-rutaexpress-notificaciones.git || (cd ms-rutaexpress-notificaciones && git pull)
git clone https://github.com/clmoralesl/ms-rutaexpress-auditoria.git || (cd ms-rutaexpress-auditoria && git pull)
git clone https://github.com/clmoralesl/ms-rutaexpress-reportes.git || (cd ms-rutaexpress-reportes && git pull)

# Inyectar dinamicamente la URL del API Gateway en el frontend antes de la compilacion Docker
if [ -n "$API_GATEWAY_URL" ]; then
  echo "Inyectando API Gateway URL ($API_GATEWAY_URL) en environment.prod.ts..."
  sed -i "s|apiUrl: '.*'|apiUrl: '${API_GATEWAY_URL}'|g" /opt/rutaexpress/rutaexpress-frontend/src/environments/environment.prod.ts
fi

echo "=== [2.1] Preparando directorio para Oracle Cloud Wallet ==="
mkdir -p /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/wallet
echo "Directorio de wallet preparado. La inyeccion de certificados se realiza post-arranque."

echo "=== [3/6] Escribiendo variables de entorno unificadas (.env) ==="
cat << EOF > /opt/rutaexpress/.env
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
cp /opt/rutaexpress/.env /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/.env

# Enlazar microservicios dentro de RUTAEXPRESS_VGUARDIA_CMORALES para rutas relativas de compose.yml
for repo in rutaexpress-frontend ms-rutaexpress-bff ms-rutaexpress-envios ms-rutaexpress-catalogo ms-rutaexpress-notificaciones ms-rutaexpress-auditoria ms-rutaexpress-reportes; do
  [ -e "/opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/$repo" ] || ln -s "/opt/rutaexpress/$repo" "/opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/$repo"
done

echo "=== [4/6] Generando certificados SSL para Nginx en la nube ==="
mkdir -p /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/nginx/certs/localhost.key \
    -out /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES/infra/nginx/certs/localhost.crt \
    -subj "/C=CL/ST=Region Metropolitana/L=Santiago/O=RutaExpress SaaS/OU=Cloud/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "=== [5/6] Construyendo y levantando la suite de microservicios con Docker Compose ==="
cd /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES

# Levantar todos los microservicios, frontend y Nginx HTTPS
docker compose -f infra/apps/compose.yml up -d --build

echo "=== [6/6] Verificando contenedores activos en ec2-apps ==="
sleep 15
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Generar script de actualizacion en caliente para cambios de GitHub
cat << 'EOF' > /opt/rutaexpress/actualizar.sh
#!/usr/bin/env bash
set -euo pipefail
echo "=== Sincronizando repositorios desde GitHub ==="
cd /opt/rutaexpress
for repo in RUTAEXPRESS_VGUARDIA_CMORALES rutaexpress-frontend ms-rutaexpress-bff ms-rutaexpress-envios ms-rutaexpress-catalogo ms-rutaexpress-notificaciones ms-rutaexpress-auditoria ms-rutaexpress-reportes; do
  if [ -d "$repo" ]; then
    echo "Actualizando $repo (origin/main)..."
    git -C "$repo" fetch origin main
    git -C "$repo" reset --hard origin/main
  fi
done
cd /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES
echo "Reconstruyendo y desplegando contenedores actualizados..."
docker compose -f infra/apps/compose.yml up -d --build
echo "=== Actualizacion completada exitosamente ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF
chmod +x /opt/rutaexpress/actualizar.sh

echo "=== Bootstrap ec2-apps completado exitosamente ==="
