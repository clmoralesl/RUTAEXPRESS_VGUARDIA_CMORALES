# Estado Actual del Proyecto y Contexto de Continuidad (Hand-off)

**Fecha de actualizacion:** 18 de Octubre, 2026  
**Proposito:** Este documento sirve como punto de partida oficial y contexto inmediato (Hand-off) para situarse en el estado exacto del proyecto, continuando con el **Issue #24 (Sprint 2)**.

---

## 1. Contexto General y Reglas Innegociables (.agents/AGENTS.md)

### Arquitectura Polirepo / Ecosistema
- **Repositorio Hub (Coordinacion, Infraestructura y Docs):** `RUTAEXPRESS_VGUARDIA_CMORALES`
- **Frontend Web:** `rutaexpress-frontend` (Angular 20, Nginx, MSAL Azure AD)
- **BFF (Backend For Frontend):** `ms-rutaexpress-bff` (Spring Boot 3.x, OAuth2 Resource Server, Puerto 8080)
- **Microservicio Envios:** `ms-rutaexpress-envios` (Spring Boot 3.x, Oracle Cloud DB `USER_ENVIOS`, Puerto 8081)
- **Microservicio Catalogo:** `ms-rutaexpress-catalogo` (Spring Boot 3.x, Oracle Cloud DB `USER_CATALOGO`, Puerto 8082)
- **Microservicio Notificaciones:** `ms-rutaexpress-notificaciones` (Spring Boot 3.x, Consumidor RabbitMQ, Puerto 8083)
- **Microservicio Auditoria:** `ms-rutaexpress-auditoria` (Spring Boot 3.x, Consumidor Kafka, Oracle Cloud DB `USER_AUDITORIA`, Puerto 8084)
- **Microservicio Reportes (Proximo):** `ms-rutaexpress-reportes` (Spring Boot 3.x, Consumidor Kafka, Analitica, Puerto 8086)

### Reglas Estrictas de Git y Desarrollo
1. **Idioma de Commits:** Todos los mensajes de commit DEBEN ser en **español** bajo estandar Conventional Commits (`feat: ...`, `fix: ...`, `infra: ...`, `docs: ...`, `chore: ...`).
2. **Aprobacion Obligatoria:** NUNCA realizar commits ni pushes automaticos sin autorizacion explicita previa del usuario.
3. **Nombres en Español:** Todos los endpoints de las API y repositorios DEBEN estar obligatoriamente en **español** (ej: `/api/publico/salud`, `/api/envios`, repositorio `ms-rutaexpress-auditoria`).
4. **Formato de Ramas:** Nombres descriptivos en español que terminen obligatoriamente con el numero del issue (ej: `feat/inicializar-ms-rutaexpress-auditoria-issue-23`, `feat/inicializar-ms-rutaexpress-reportes-issue-24`).
5. **Plantilla de Pull Request Obligatoria:** Por cada push realizado al considerar completado un Issue, se DEBE proporcionar una plantilla de Pull Request (PR) en español lista para copiar y pegar en GitHub, con titulo, descripcion, tipo de cambio, criterios validados, evidencias y la clausula `Closes #<numero>`.
6. **Prohibicion Estricta de Emoticonos y Emojis:** Queda estrictamente prohibido el uso de emoticonos o emojis en respuestas, documentacion tecnica, mensajes de commit, plantillas de pull request y codigo fuente. Toda la comunicacion debe mantener un tono formal, sobrio y tecnico.

---

## 2. Resumen del Sprint 1 (Completado y Aprobado)
- Issues `#1` al `#16`, `#28` y `#29` cerrados.
- Autenticacion Azure AD (MSAL Angular + Spring Resource Server BFF con RBAC).
- CRUD basico y maquina de estados de envios sobre Oracle Cloud DB (Autonomous DB con Wallet).

---

## 3. Estado del Backlog (Sprint 2 - Asincronia y Analitica)

### Issues Completados del Sprint 2
- **Issue #17: [Infra] Cluster RabbitMQ con Topologia de 6 Colas y DLQ**
  - Implementado en `infra/mq/compose.yml` (Puertos 5672 y 15672). Exchanges: `cmd.direct`, `cmd.topic`, `cmd.dead.dlx`.
  - Pull Request #45 mergeado en `main`.

- **Issue #18: [Infra] Cluster Kafka, Zookeeper y Kafka UI**
  - Implementado en `infra/kafka/compose.yml` (Zookeeper 2181, Kafka 9092, Kafka UI 8085).
  - Topicos aprovisionados: `shipments.events`, `audit.timeline` y sus DLTs (`*.DLT`) con 3 particiones y retencion configurada.
  - Pull Request #46 mergeado en `main`.

- **Issue #19: [Backend] Inicializar ms-rutaexpress-catalogo (Flota, Capacidad y Tarifas)**
  - Microservicio Spring Boot 3.3.5 / Java 17 en puerto 8082 (`clmoralesl/ms-rutaexpress-catalogo`).
  - Endpoint atomico `PATCH /api/catalogo/servicios/{id}/descontar-capacidad` con rechazo HTTP 409 Conflict.
  - PR #47 mergeado en `main`.

- **Issue #20: [Backend] Integrar Publicador RabbitMQ y Descuento de Capacidad en ms-rutaexpress-envios**
  - Mensajeria AMQP estructurada con `MensajeEnvelope<T>`.
  - Descuento automatico de cupo vehicular y envio de mensajes para email y bodega al transicionar a `ACEPTADO`.
  - PR #6 mergeado en `main`.

- **Issue #21: [Backend] Inicializar ms-rutaexpress-notificaciones (Consumidor RabbitMQ, Tickets y DLQ)**
  - Microservicio Spring Boot 3.3.5 / Java 17 en puerto 8083 (`clmoralesl/ms-rutaexpress-notificaciones`).
  - Consumidores `@RabbitListener` con confirmacion manual, generacion de tickets termicos y endpoint de metricas.
  - PR #48 sincronizado con `main`.

- **Issue #22: [Backend] Integrar Productor Kafka en ms-rutaexpress-envios (Event Sourcing Logistico)**
  - Productor `KafkaTemplate` con serializador JSON y particionamiento por `key = envioId.toString()`.
  - Emision de eventos estructurados inmutables hacia `shipments.events` en todas las transiciones del ciclo de vida.
  - Resiliencia operativa no bloqueante y 25 pruebas unitarias/integrales en verde.
  - Rama `feat/productor-kafka-envios-issue-22` subida y lista para PR.

- **Issue #23: [Backend] Inicializar ms-rutaexpress-auditoria (Consumidor Kafka, Timeline Inmutable)**
  - Microservicio Spring Boot 3.3.5 / Java 17 en puerto 8084 (`clmoralesl/ms-rutaexpress-auditoria`).
  - Consumidor `@KafkaListener(topics = "shipments.events", groupId = "auditoria-group")`.
  - Persistencia append-only inmutable en esquema `USER_AUDITORIA` (tabla `HISTORIAL_AUDITORIA` con indices en `envio_id`, `usuario_email` y `fecha_evento`).
  - Idempotencia garantizada por `eventoId` (UUID).
  - Endpoints: `GET /api/auditoria/envios/{id}`, `GET /api/auditoria/eventos`, `GET /api/publico/salud`.
  - 11 pruebas automatizadas en verde (unitarias, MockMvc e integracion E2E contra cluster real Kafka `localhost:9092`).
  - Rama `feat/inicializar-ms-rutaexpress-auditoria-issue-23` subida y lista para PR.

- **Issue #24: [Backend] Inicializar ms-rutaexpress-reportes (Consumidor Kafka y Motor Analitico)**
  - Microservicio Spring Boot 3.3.5 / Java 17 en puerto 8086 (`clmoralesl/ms-rutaexpress-reportes`).
  - Consumidor `@KafkaListener(topics = "shipments.events", groupId = "reportes-group")`.
  - Entidad analitica `RegistroAnaliticoEnvio` con calculo de `leadTimeHoras`.
  - Consultas analiticas agregadas en repositorio para KPIs, distribucion de estados, Lead Time y rankings.
  - Endpoints: `GET /api/reportes/kpis`, `GET /api/reportes/top-servicios`, `GET /api/reportes/rendimiento-couriers`, `GET /api/publico/salud`.
  - 11 pruebas automatizadas en verde (unitarias, controllers e integracion E2E contra cluster real Kafka `localhost:9092`).
  - Rama `feat/inicializar-ms-rutaexpress-reportes-issue-24` subida y lista para PR.

- **Issue #35: [Backend] Orquestacion y Agregacion en ms-rutaexpress-bff**
  - Implementado en `clmoralesl/ms-rutaexpress-bff` (puerto 8080).
  - Proxy centralizado `BffProxyService` con propagacion automatica de Token JWT (Token Relay) y query parameters.
  - Manejo de fallback estandarizado en formato JSON (`ErrorRespuestaBff`, HTTP 503) ante fallos downstream (`ResourceAccessException`).
  - Controladores con seguridad declarativa RBAC (`@PreAuthorize`):
    - `CatalogoBffController`: `/api/bff/catalogo/**` hacia `ms-rutaexpress-catalogo` (8082).
    - `AuditoriaBffController`: `/api/bff/auditoria/**` hacia `ms-rutaexpress-auditoria` (8084).
    - `ReportesBffController`: `/api/bff/reportes/**` hacia `ms-rutaexpress-reportes` (8086).
  - Conectividad actualizada con `JdkClientHttpRequestFactory` con soporte de `PATCH` y timeouts configurables.
  - Endpoint de salud `/api/publico/salud`.
  - 24/24 pruebas automatizadas en verde (unitarias, controllers MockMvc y seguridad RBAC).
  - Rama `feat/orquestacion-bff-catalogo-auditoria-reportes-issue-35` subida a GitHub.

---

- **Issue #39: [DevOps] Proxy Inverso Nginx con HTTPS para Frontend y Backend (Resolver MSAL sin flags y CORS)**
  - Implementado en `infra/nginx` y registrado en `infra/apps/compose.yml`.
  - Servidor Nginx 1.27 en puerto 443 (HTTPS) con redirección automática 301 desde puerto 80 (HTTP).
  - Certificados SSL X.509 generados (`localhost.crt` y `localhost.key`) con extensiones Subject Alternative Name (`DNS:localhost`, `IP:127.0.0.1`).
  - Fachada unificada Same-Origin:
    - `/` redirige al frontend Angular (`rutaexpress-frontend:80`).
    - `/api/` redirige al BFF (`ms-rutaexpress-bff:8080/api/`).
  - Habilitación de Contexto Seguro (`window.isSecureContext = true`) que resuelve definitivamente el error `crypto_nonexistent` de MSAL Angular sin requerir flags de navegador.
  - Manejo centralizado de preflights CORS `OPTIONS` con respuesta inmediata HTTP 204 No Content.
  - Script de validación automatizada `infra/nginx/verificar_nginx.ps1` con 5/5 pruebas exitosas.
  - Rama `infra/proxy-nginx-https-issue-39` lista para PR en el repositorio Hub.

---

## 4. Proximo Issue a Resolver: Issue #26

- **ID del Issue:** `#26`
- **Titulo en GitHub:** `[Infra] Despliegue Multi-Instancia en AWS (EC2 Apps, EC2 MQ, EC2 Kafka)`
- **Asignado a:** Claudio (`@clmoralesl`)
- **Repositorio:** `RUTAEXPRESS_VGUARDIA_CMORALES`
- **Rama a Crear:** `infra/despliegue-multi-instancia-aws-issue-26`
- **Dependencias:** Issues #17, #18, #19, #20, #21, #22, #23, #24, #35, #39 (Toda la infraestructura y microservicios funcionales en local)

### Objetivos del Issue #26:
1. Definicion de infraestructura en AWS mediante Terraform / Scripts para despliegue distribuido:
   - Instancia `ec2-apps`: Frontend (Nginx HTTPS), BFF y microservicios de dominio.
   - Instancia `ec2-mq`: Cluster RabbitMQ con topologia de colas y DLQ.
   - Instancia `ec2-kafka`: Zookeeper, Apache Kafka y Kafka UI.
2. Security Groups estrictos que permitan comunicacion interna entre instancias en los puertos AMQP (5672) y Kafka (9092), exponiendo publicamente solo HTTPS (443) y SSH administrativo.
3. Scripts de aprovisionamiento automatizado y manual de despliegue.



