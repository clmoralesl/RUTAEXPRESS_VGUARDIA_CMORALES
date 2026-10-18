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
