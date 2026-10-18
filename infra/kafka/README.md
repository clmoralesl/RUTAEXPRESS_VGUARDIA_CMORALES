# Infraestructura Apache Kafka y Zookeeper - RutaExpress (Issue #18)

Este directorio contiene la definición contenerizada de la plataforma de streaming de eventos distribuida de **RutaExpress**, compuesta por **Apache Kafka**, **Zookeeper** y la consola gráfica **Kafka UI**.

---

## 1. Arquitectura y Puertos

| Servicio | Puerto Host | Puerto Contenedor | Protocolo | Propósito |
|---|---|---|---|---|
| **Kafka Broker** | `9092` | `9092` (Host) / `29092` (Docker) | Kafka PLAINTEXT | Conexión de productores y consumidores Spring Boot (`ms-rutaexpress-envios`, `ms-rutaexpress-auditoria`, `ms-rutaexpress-reportes`) |
| **Zookeeper** | `2181` | `2181` | TCP | Coordinación del clúster, metadatos y líderes de partición |
| **Kafka UI** | `8085` | `8080` | HTTP | Interfaz web para monitoreo de tópicos, particiones, offsets y mensajes en tiempo real |

* **URL Kafka UI:** [http://localhost:8085](http://localhost:8085)
* **Clúster Name:** `rutaexpress-cluster`

---

## 2. Topología de Tópicos Requeridos

Los tópicos se crean automáticamente en el arranque mediante el servicio contenedorizado `kafka-init`.

| Tópico | Particiones | Factor Replicación | Clave de Partición (`Key`) | Política de Limpieza | Retención | Propósito en el Negocio |
|---|---|---|---|---|---|---|
| **`shipments.events`** | `3` | `1` | `envioId.toString()` | `delete` | 7 días (`604800000 ms`) | Tópico troncal de eventos de ciclo de vida (`CREADO`, `ACEPTADO`, `EN_BODEGA`, `EN_RUTA`, `ENTREGADO`, `CANCELADO`). Alimenta auditoría y reportería. |
| **`audit.timeline`** | `3` | `1` | `envioId.toString()` | `compact,delete` | 30 días (`2592000000 ms`) | Historial inmutable para trazabilidad legal y timeline interactivo de auditoría. |
| **`shipments.events.DLT`** | `3` | `1` | `envioId.toString()` | `delete` | 14 días (`1209600000 ms`) | Dead Letter Topic para errores fatales de procesamiento o deserialización en consumidores de envíos. |
| **`audit.timeline.DLT`** | `3` | `1` | `envioId.toString()` | `delete` | 14 días (`1209600000 ms`) | Dead Letter Topic para errores en el pipeline de auditoría. |

### Estrategia de Particionamiento
* Todos los eventos se publican con la clave obligatoria `key = envioId.toString()`.
* Esto garantiza que **todos los eventos de un mismo paquete siempre caigan en la misma partición**, preservando el orden secuencial estricto del ciclo de vida sin bloquear el procesamiento concurrente de otros envíos.

---

## 3. Guía de Ejecución Rápida

### Levantar la Infraestructura
```bash
docker compose -f infra/kafka/compose.yml up -d
```

### Ejecutar Suite de Verificación Autónoma
```powershell
powershell -ExecutionPolicy Bypass -File infra/kafka/verificar_kafka.ps1
```

### Detener los Servicios
```bash
docker compose -f infra/kafka/compose.yml down
```

### Reinicio Limpio con Eliminación de Volúmenes
```bash
docker compose -f infra/kafka/compose.yml down -v
```
