# Arquitectura de Despliegue Multi-Instancia en AWS (RutaExpress)

## Descripcion General
Este modulo (`infra/aws-ec2`) implementa la infraestructura como codigo (Terraform) y los scripts de aprovisionamiento automatizado (User Data) para trasladar la arquitectura desacoplada de RutaExpress desde el entorno local hacia maquinas virtuales Amazon EC2 segmentadas por rol y responsabilidad tecnica.

---

## Diagrama de Arquitectura y Flujo de Comunicacion

```
                           [ Internet / Clientes Web ]
                                        │
                                        ▼ (HTTPS :443)
┌─────────────────────────────────────────────────────────────────────────────┐
│                            VPC (10.10.0.0/16)                               │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Subred Publica (10.10.1.0/24)                      │  │
│  │                                                                       │  │
│  │   ┌───────────────────────────────────────────────────────────────┐   │  │
│  │   │                     Instancia ec2-apps                        │   │  │
│  │   │                    (IP Publica + Privada)                     │   │  │
│  │   │                                                               │   │  │
│  │   │  • Nginx Reverse Proxy (HTTPS :443 / Contexto Seguro MSAL)    │   │  │
│  │   │  • Backend For Frontend - ms-rutaexpress-bff (:8080)          │   │  │
│  │   │  • Frontend Web Angular - rutaexpress-frontend                │   │  │
│  │   │  • Microservicios de Dominio (Envios, Catalogo, etc.)         │   │  │
│  │   └──────────────────────┬──────────────────────┬─────────────────┘   │  │
│  └──────────────────────────┼──────────────────────┼─────────────────────┘  │
│                             │                      │                        │
│                             │ AMQP (:5672)         │ Kafka (:9092)          │
│                             │ (Solo sg_ec2_apps)   │ (Solo sg_ec2_apps)     │
│                             ▼                      ▼                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Subred Brokers (10.10.2.0/24)                      │  │
│  │                                                                       │  │
│  │   ┌─────────────────────────────┐   ┌─────────────────────────────┐   │  │
│  │   │      Instancia ec2-mq       │   │    Instancia ec2-kafka      │   │  │
│  │   │                             │   │                             │   │  │
│  │   │ • RabbitMQ 3.13 (:5672)     │   │ • Apache Kafka (:9092)      │   │  │
│  │   │ • Topologia de 6 Colas + DLQ│   │ • Zookeeper (:2181)         │   │  │
│  │   │ • Management UI (:15672)    │   │ • Kafka UI (:8085)          │   │  │
│  │   └─────────────────────────────┘   └─────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Matriz de Security Groups y Segmentacion Estricta

| Security Group | Puerto / Protocolo | Origen Autorizado | Proposito |
| :--- | :--- | :--- | :--- |
| **`sg_ec2_apps`** | `443/TCP` (HTTPS) | `0.0.0.0/0` (Internet) | Trafico seguro cifrado hacia Nginx Reverse Proxy y MSAL |
| | `80/TCP` (HTTP) | `0.0.0.0/0` (Internet) | Redireccion permanente HTTP 301 a HTTPS |
| | `22/TCP` (SSH) | `var.allowed_admin_cidr` | Gestion y administracion tecnica remota |
| **`sg_ec2_mq`** | `5672/TCP` (AMQP) | **`sg_ec2_apps` (Exclusivo)** | Aislamiento estricto: solo el backend produce/consume colas |
| | `15672/TCP` (HTTP) | `var.allowed_admin_cidr` | Panel de monitoreo RabbitMQ Management UI |
| | `22/TCP` (SSH) | `var.allowed_admin_cidr` | Administracion remota |
| **`sg_ec2_kafka`** | `9092/TCP` (Kafka) | **`sg_ec2_apps` (Exclusivo)** | Aislamiento estricto: solo el backend produce/consume eventos |
| | `8085/TCP` (HTTP) | `var.allowed_admin_cidr` | Panel de inspeccion Kafka UI |
| | `22/TCP` (SSH) | `var.allowed_admin_cidr` | Administracion remota |

---

## Estructura del Modulo

- `main.tf`: Declaracion de la VPC, subredes, tablas de enrutamiento, reglas de aislamiento de Security Groups y las 3 instancias EC2 (`ec2_apps`, `ec2_mq`, `ec2_kafka`).
- `variables.tf`: Parametrizacion de region AWS, tipos de instancia (`t3.medium`, `t3.small`), rangos CIDR y claves SSH.
- `outputs.tf`: Exportacion automatica de IPs publicas y privadas, comandos SSH formateados y URLs directas a los paneles.
- `scripts/bootstrap-mq.sh`: Script de inicializacion para `ec2-mq` que instala Docker, aprovisiona RabbitMQ 3.13 y declara la topologia de 6 colas, 3 exchanges y Dead Letter Queues.
- `scripts/bootstrap-kafka.sh`: Script para `ec2-kafka` que aprovisiona Zookeeper, Kafka y Kafka UI, configurando `KAFKA_ADVERTISED_LISTENERS` con la IP privada para enrutamiento interno.
- `scripts/bootstrap-apps.sh`: Script para `ec2-apps` que inyecta las IPs privadas de `ec2-mq` y `ec2-kafka` en el archivo `.env`, genera certificados SSL y levanta la suite de microservicios tras Nginx HTTPS.
- `verificar_despliegue_aws.ps1`: Suite automatizada de comprobacion de reglas de aislamiento de red y sintaxis HCL.

---

## Procedimiento de Despliegue en AWS

1. **Configurar Credenciales de AWS**:
   ```powershell
   $env:AWS_ACCESS_KEY_ID="tu-access-key"
   $env:AWS_SECRET_ACCESS_KEY="tu-secret-key"
   $env:AWS_SESSION_TOKEN="tu-session-token" # Si se utiliza AWS Academy / Learner Lab
   ```

2. **Validar la Configuracion de Infraestructura**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/aws-ec2/verificar_despliegue_aws.ps1
   ```

3. **Ejecutar Despliegue con Terraform**:
   ```bash
   cd infra/aws-ec2
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. **Comprobar Conectividad Cloud**:
   - Abrir en el navegador: `https://<ec2_apps_public_ip>/salud-proxy`
   - Monitorear RabbitMQ: `http://<ec2_mq_public_ip>:15672/`
   - Monitorear Kafka: `http://<ec2_kafka_public_ip>:8085/`

5. **Inyectar el Oracle Wallet**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/aws-ec2/inyectar_wallet.ps1 -KeyPath <ruta-a-labsuser.pem>
   ```
   El script copia el wallet a `ec2-apps`, recrea envios, catalogo, auditoria y BFF, y verifica que los cuatro contenedores queden en ejecucion con su nombre normal. Termina con codigo 0 si todo queda bien y con un codigo distinto de 0 (y un mensaje en rojo) si falla `scp`, `ssh` o algun contenedor no queda en ejecucion.

---

## Recuperacion tras una inyeccion interrumpida

Si una recreacion de contenedores se corta a mitad (por ejemplo, porque se perdio la sesion SSH), los servicios pueden quedar detenidos o con nombres temporales del tipo `<id>_ms-rutaexpress-envios`.

1. Diagnosticar desde `ec2-apps`:
   ```bash
   sudo docker ps -a --format '{{.Names}} {{.Status}}'
   ```
2. Recrear los cuatro servicios con las imagenes ya construidas (sin compilar de nuevo):
   ```bash
   cd /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES
   sudo docker compose -f infra/apps/compose.yml up -d --no-build --force-recreate ms-rutaexpress-envios ms-rutaexpress-catalogo ms-rutaexpress-auditoria ms-rutaexpress-bff
   ```
3. Repetir el paso 1 y confirmar que los cuatro aparecen como `Up` con su nombre normal.
