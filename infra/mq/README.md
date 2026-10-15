# Infraestructura RabbitMQ - RutaExpress (Issue #17)

Este directorio contiene la definición contenerizada y la topología declarativa completa para el broker de mensajería asíncrona de **RutaExpress** (RabbitMQ 3.13 con Management UI y Dead Letter Queue).

---

## 1. Arquitectura y Puertos

| Servicio | Puerto Host | Puerto Contenedor | Protocolo | Propósito |
|---|---|---|---|---|
| **RabbitMQ AMQP** | `5672` | `5672` | AMQP 0-9-1 | Conexión para microservicios Spring Boot (`ms-rutaexpress-envios`, `ms-rutaexpress-notificaciones`) |
| **Management UI & API** | `15672` | `15672` | HTTP | Interfaz web de administración y API REST para inspección de colas |

### Credenciales de Acceso
* **Usuario Administrador:** `guest` (o `rutaexpress`)
* **Contraseña:** `guest` (o `rutaexpress123`)
* **Virtual Host:** `/`
* **URL Management UI:** [http://localhost:15672](http://localhost:15672)

---

## 2. Topología Declarativa (`definitions.json`)

Toda la topología se inicializa de forma **100% declarativa y automática** al levantar el contenedor mediante la directiva `load_definitions` de RabbitMQ. No requiere configuración manual.

### 2.1 Exchanges Declarados (3)
1. **`cmd.direct`** (Direct): Para comandos directos punto a punto con enrutamiento exacto.
2. **`cmd.topic`** (Topic): Para eventos jerárquicos y patrones de suscripción con comodines (`*`, `#`).
3. **`cmd.dead.dlx`** (Direct): Dead Letter Exchange dedicado a capturar mensajes rechazados (`NACK requeue=false`) o expirados por TTL.

### 2.2 Colas y Dead Letter Queues (6 Colas)
Todas las colas son durables y cuentan con límites de retención y longitud para evitar saturación de memoria.

| Cola Principal | Routing Keys de Entrada | Dead Letter Exchange (DLX) | Dead Letter Routing Key (DLK) | Cola DLQ Destino | TTL Principal | Max Length |
|---|---|---|---|---|---|---|
| **`q.cmd.email`** | `cmd.direct: email.send`<br>`cmd.topic: email.*` | `cmd.dead.dlx` | `email.dead` | **`q.cmd.email.dlq`** | 24 h (86.400.000 ms) | 10.000 msgs |
| **`q.cmd.warehouse`** | `cmd.direct: warehouse.ticket`<br>`cmd.topic: warehouse.#` | `cmd.dead.dlx` | `warehouse.dead` | **`q.cmd.warehouse.dlq`** | 24 h (86.400.000 ms) | 10.000 msgs |
| **`q.cmd.label`** | `cmd.direct: label.gen`<br>`cmd.topic: label.*` | `cmd.dead.dlx` | `label.dead` | **`q.cmd.label.dlq`** | 24 h (86.400.000 ms) | 10.000 msgs |

### 2.3 Matriz de Enlaces (Bindings)
* **`cmd.direct`:**
  - `email.send` -> `q.cmd.email`
  - `warehouse.ticket` -> `q.cmd.warehouse`
  - `label.gen` -> `q.cmd.label`
* **`cmd.topic`:**
  - `email.*` -> `q.cmd.email`
  - `warehouse.#` -> `q.cmd.warehouse`
  - `label.*` -> `q.cmd.label`
* **`cmd.dead.dlx`:**
  - `email.dead`, `email.send`, `q.cmd.email.dlq` -> `q.cmd.email.dlq`
  - `warehouse.dead`, `warehouse.ticket`, `q.cmd.warehouse.dlq` -> `q.cmd.warehouse.dlq`
  - `label.dead`, `label.gen`, `q.cmd.label.dlq` -> `q.cmd.label.dlq`

---

## 3. Guía de Ejecución Rápida

### Levantar el Broker
```bash
docker compose -f infra/mq/compose.yml up -d
```

### Ejecutar la Suite de Verificación Autónoma
```powershell
powershell -ExecutionPolicy Bypass -File infra/mq/verificar_mq.ps1
```

### Detener el Broker
```bash
docker compose -f infra/mq/compose.yml down
```

### Reinicio Limpio con Eliminación de Volúmenes
```bash
docker compose -f infra/mq/compose.yml down -v
```
