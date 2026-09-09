# Backlog RutaExpress - Desglose de Tareas

Este documento contiene el backlog del proyecto desglosado en tareas modulares, estructuradas por Sprints para cubrir el 100% de la pauta de evaluación.
El formato utilizado permite la sincronización automática con GitHub Issues (separando cada Issue con `---`).

---
## Resumen de Sprints y Cobertura
- **Sprint 1 - Evaluación Parcial 1 (16 Issues):** Autenticación Azure AD (MSAL), BFF Spring Boot con RBAC, Microservicio Shipments con BD Cloud, Contenedores Docker, Despliegue en AWS EC2, Protección perimetral con AWS API Gateway (JWT Authorizer) y Vistas funcionales en Angular.
- **Sprint 2 - Asincronía, Analítica e Infraestructura Avanzada (10 Issues):** Clúster RabbitMQ con DLQ, Clúster Kafka y Zookeeper, Microservicios de Catálogo, Notificaciones, Auditoría y Reportes (KPIs), Dashboard en Frontend y Despliegue multi-EC2 en AWS.

---

## Sprint 1 - Evaluación Parcial 1 (Seguridad, BFF, EC2, API Gateway y CRUD Envíos)
*Objetivo: Cumplir con el 100% de la pauta de evaluación N°1, logrando un flujo de autenticación seguro de extremo a extremo y pantallas funcionales conectadas a la nube.*

---
**Title:** [Infra] Configurar App Registration en Azure AD
**Labels:** security, devops
**Size:** S
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Configurar el entorno de identidad (IDaaS) en Azure Active Directory / Microsoft Entra ID para el login corporativo.

**Criterios de Aceptación:**
- [x] La aplicación "RutaExpress" existe en Azure AD.
- [x] Se obtienen las credenciales (`clientId` y `tenantId`).
- [x] La URL de redirección (ej. `http://localhost:4200`) está configurada para el Frontend.
- [x] La API (App ID URI) está expuesta con los scopes correspondientes (`api://<API_CLIENT_ID>/access_as_user`).
- [x] Las credenciales de desarrollo están documentadas en `.env.example`.

---
**Title:** [Backend] Inicializar ms-rutaexpress-bff (Resource Server OAuth2)
**Labels:** backend, security, task
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Crear el microservicio Backend For Frontend (BFF) en Spring Boot que actúa como punto de entrada de la aplicación, configurado como Resource Server OAuth2 para validar tokens JWT emitidos por Azure AD (Entra ID).

**Criterios de Aceptación:**
- [ ] Proyecto Spring Boot 3.x inicializado con Java 17 en `BACKEND/ms-rutaexpress-bff`.
- [ ] Se valida que el token recibido pertenezca al `issuer-uri` y `jwk-set-uri` de Azure AD.
- [ ] Retorna HTTP 401 si se intenta consumir un endpoint protegido sin token o con token inválido.
- [ ] Expone endpoint de salud público `/actuator/health` o `/api/public/health` con HTTP 200.

---
**Title:** [Backend] Configurar extracción de Roles y RBAC en ms-rutaexpress-bff
**Labels:** backend, security
**Size:** S
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Backend] Inicializar ms-rutaexpress-bff*
Parsear los claims del token JWT de Azure AD para manejar autorización basada en roles (RBAC) en el BFF.

**Criterios de Aceptación:**
- [ ] El `JwtAuthenticationConverter` extrae los roles y claims del token (`roles` o `groups`) mapeándolos a `ROLE_ADMIN`, `ROLE_DESPACHADOR`, `ROLE_CLIENTE`.
- [ ] Endpoint de prueba (ej. `/api/test-admin`) retorna HTTP 403 Forbidden si el rol no coincide.
- [ ] Respuestas de error 401 y 403 debidamente formateadas en JSON con código y mensaje estándar.

---
**Title:** [Backend] Inicializar ms-rutaexpress-shipments y conexión a BD Cloud
**Labels:** backend, database, task
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Crear el microservicio de negocio para el ciclo de vida de los envíos con persistencia en Base de Datos Cloud (Oracle Cloud / RDS).

**Criterios de Aceptación:**
- [ ] Proyecto Spring Boot 3.x inicializado en `BACKEND/ms-rutaexpress-shipments`.
- [ ] Conexión exitosa a la base de datos cloud configurada mediante JPA/Hibernate.
- [ ] Entidad `Shipment` y repositorio `ShipmentRepository` implementados correctamente.
- [ ] Scripts o migraciones iniciales para estructura de tablas.

---
**Title:** [Backend] CRUD Básico y Validación de Máquina de Estados en ms-rutaexpress-shipments
**Labels:** backend, feature
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Backend] Inicializar ms-rutaexpress-shipments*
Habilitar las operaciones de creación, consulta y transición de estados del ciclo de vida de envíos.

**Criterios de Aceptación:**
- [ ] `POST /api/shipments` crea un envío en estado "CREADO" y retorna HTTP 201 con ID generado.
- [ ] `GET /api/shipments/{id}` retorna HTTP 200 con el detalle o HTTP 404 si no existe.
- [ ] `GET /api/shipments` retorna el listado de envíos con soporte a filtros (estado, fechas).
- [ ] `PUT /api/shipments/{id}/status` valida la progresión estricta: `CREADO -> ACEPTADO -> EN_BODEGA -> EN_RUTA -> ENTREGADO` (o `CANCELADO`).
- [ ] Transiciones inválidas son rechazadas con HTTP 400 Bad Request y mensaje descriptivo.

---
**Title:** [Backend] Configurar Enrutamiento en ms-rutaexpress-bff hacia ms-rutaexpress-shipments
**Labels:** backend, feature
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Backend] Inicializar ms-rutaexpress-bff, [Backend] CRUD Básico ms-rutaexpress-shipments*
Configurar el BFF para orquestar y reenviar peticiones autenticadas y autorizadas hacia el microservicio `ms-rutaexpress-shipments`.

**Criterios de Aceptación:**
- [ ] Endpoints `/api/bff/shipments/**` enrutan de forma segura hacia el servicio de envíos.
- [ ] Propagación de identidad y contexto del usuario autenticado.
- [ ] Manejo de resiliencia y timeouts en caso de indisponibilidad del servicio de envíos.

---
**Title:** [DevOps] Dockerizar microservicios (Dockerfile y compose.yml de apps)
**Labels:** devops, task
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Crear las imágenes Docker y la orquestación para levantar los microservicios backend de forma contenerizada.

**Criterios de Aceptación:**
- [ ] `Dockerfile` multi-stage optimizado para `ms-rutaexpress-bff`.
- [ ] `Dockerfile` multi-stage optimizado para `ms-rutaexpress-shipments`.
- [ ] Archivo `infra/apps/compose.yml` que levanta ambos servicios en una red común pasando variables de entorno.
- [ ] Verificación local de que los contenedores levantan y comunican sin errores.

---
**Title:** [Infra] Despliegue de microservicios en instancia AWS EC2
**Labels:** devops, infra
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [DevOps] Dockerizar microservicios*
Aprovisionar y configurar una instancia AWS EC2 para ejecutar los contenedores de los microservicios backend con Docker Compose.

**Criterios de Aceptación:**
- [ ] Instancia EC2 en ejecución con Docker y Docker Compose instalados.
- [ ] Security Groups configurados para permitir tráfico únicamente desde los puertos autorizados (SSH y puerto HTTP/BFF).
- [ ] Contenedores de `ms-rutaexpress-bff` y `ms-rutaexpress-shipments` activos y respondiendo correctamente.

---
**Title:** [Infra] Configurar AWS API Gateway (HTTP API + JWT Authorizer Azure AD)
**Labels:** devops, security, infra
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Configurar la capa perimetral del sistema en AWS API Gateway para proteger el backend desplegado en EC2.

**Criterios de Aceptación:**
- [ ] HTTP API creada en AWS API Gateway.
- [ ] JWT Authorizer configurado con Issuer `https://login.microsoftonline.com/<TENANT_ID>/v2.0` y Audience `api://<BACKEND_CLIENT_ID>`.
- [ ] Peticiones sin token o con token inválido retornan HTTP 401 a nivel perimetral antes de alcanzar la instancia EC2.
- [ ] Peticiones válidas son enrutadas exitosamente hacia la IP/DNS de la instancia EC2 donde corre el BFF.

---
**Title:** [Frontend] Inicializar proyecto Angular y estructura base
**Labels:** frontend, task
**Size:** S
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Crear la aplicación base en Angular en la carpeta `FRONTEND` configurando estándares y buenas prácticas.

**Criterios de Aceptación:**
- [ ] Proyecto Angular inicializado y compilando correctamente con `ng serve`.
- [ ] Estructura modular de carpetas (`core/`, `shared/`, `features/`).
- [ ] Variables de entorno configuradas (`environment.ts` con URLs de API Gateway y credenciales Azure AD).

---
**Title:** [Frontend] Maquetación de Layout Principal (Navbar y Sidebar)
**Labels:** frontend, feature
**Size:** S
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Frontend] Inicializar proyecto Angular*
Crear la estructura visual que encapsulará las diferentes vistas del sistema con diseño responsivo.

**Criterios de Aceptación:**
- [ ] Barra de navegación muestra el estado de sesión (nombre de usuario y rol activo).
- [ ] Menú lateral (sidebar) dinámico según los roles del usuario.
- [ ] Botón funcional de "Cerrar Sesión" que invalida el token y estado en MSAL.

---
**Title:** [Frontend] Integrar MSAL y flujo de Login/Logout
**Labels:** frontend, security
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Infra] Configurar App Registration en Azure AD, [Frontend] Inicializar proyecto Angular*
Configurar la autenticación corporativa con Azure AD mediante `@azure/msal-browser` y `@azure/msal-angular`.

**Criterios de Aceptación:**
- [ ] Botón de "Iniciar sesión con Microsoft" redirige al login oficial de Azure AD.
- [ ] Tras login exitoso, se obtiene y almacena el `access_token` JWT.
- [ ] Redirección automática a la vista privada inicial (`/dashboard` o `/shipments`).

---
**Title:** [Frontend] Implementar Guards e Interceptor MSAL apuntando a AWS API Gateway
**Labels:** frontend, security
**Size:** S
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Frontend] Integrar MSAL y flujo de Login/Logout, [Infra] Configurar AWS API Gateway*
Asegurar las rutas en el frontend y configurar la inyección automática del token hacia el endpoint de AWS API Gateway.

**Criterios de Aceptación:**
- [ ] `MsalGuard` protege todas las rutas privadas, impidiendo el acceso a usuarios no autenticados.
- [ ] `MsalInterceptor` inyecta automáticamente la cabecera `Authorization: Bearer <token>` en todas las peticiones dirigidas a la URL base del AWS API Gateway.
- [ ] Manejo de renovación silenciosa de tokens (`acquireTokenSilent`).

---
**Title:** [Frontend] Vista de Listado de Envíos
**Labels:** frontend, feature
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Frontend] Implementar Guards e Interceptor MSAL*
Implementar la vista para visualizar y filtrar los envíos consumiendo el backend a través de AWS API Gateway.

**Criterios de Aceptación:**
- [ ] Tabla interactiva que renderiza el listado de envíos.
- [ ] Filtros por estado y rango de fechas.
- [ ] Estados visuales claros de carga (`loading spinner`), error y lista vacía.

---
**Title:** [Frontend] Vista de Creación de Envíos y Transición de Estados
**Labels:** frontend, feature
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: [Frontend] Vista de Listado de Envíos*
Implementar el formulario para registrar nuevos envíos y los controles para avanzar estados según rol.

**Criterios de Aceptación:**
- [ ] Formulario reactivo con validaciones frontend (campos obligatorios, pesos, direcciones).
- [ ] Controles de avance de estado (botones/select) visibles únicamente para usuarios autorizados (`ROLE_ADMIN`, `ROLE_DESPACHADOR`).
- [ ] Notificaciones amigables ante éxito o errores devueltos por la máquina de estados.

---
**Title:** [QA] Pruebas de Integración End-to-End para Evaluación 1
**Labels:** qa, devops
**Size:** M
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
*Depende de: Todos los issues del Sprint 1*
Validación completa del flujo integrado según la rúbrica de la Evaluación Parcial 1.

**Criterios de Aceptación:**
- [ ] Flujo E2E verificado: Angular (MSAL) -> AWS API Gateway (JWT Authorizer) -> EC2 (ms-rutaexpress-bff) -> ms-rutaexpress-shipments -> BD Cloud.
- [ ] Verificación de rechazo 401 en Gateway sin token o con token inválido.
- [ ] Verificación de rechazo 403 en BFF si el rol no tiene permiso asignado.
- [ ] Documentación del flujo de pruebas y capturas de evidencia listas para la entrega.


---
## Sprint 2 - Asincronía, Analítica e Infraestructura Avanzada
*Objetivo: Integrar RabbitMQ con DLQ, Kafka para streaming de eventos y analítica en tiempo real, catálogo de couriers y despliegue distribuido en AWS.*

---
**Title:** [Infra] Crear Docker Compose para clúster RabbitMQ (infra/mq/compose.yml)
**Labels:** devops, infra
**Size:** S
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Crear la infraestructura contenerizada para RabbitMQ en alta disponibilidad con Management UI.

**Criterios de Aceptación:**
- [ ] Archivo `infra/mq/compose.yml` levanta RabbitMQ accesible en puerto 5672 y UI en 15672.
- [ ] Configuración inicial de exchanges (`cmd.direct`, `cmd.topic`, `cmd.dead.dlx`) y colas con DLQ.
- [ ] Persistencia de datos configurada mediante volúmenes.

---
**Title:** [Infra] Crear Docker Compose para clúster Kafka y Zookeeper (infra/kafka/compose.yml)
**Labels:** devops, infra
**Size:** M
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Crear la infraestructura contenerizada para Kafka, Zookeeper y Kafka UI.

**Criterios de Aceptación:**
- [ ] Archivo `infra/kafka/compose.yml` levanta Zookeeper y Kafka en el puerto 9092.
- [ ] Kafka UI disponible y accesible para inspección de tópicos.
- [ ] Tópico `shipments.events` inicializado con factor de particionamiento adecuado.

---
**Title:** [Backend] Inicializar ms-rutaexpress-catalog (Catálogo y Capacidad de Flota)
**Labels:** backend, feature
**Size:** M
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Microservicio para administrar tipos de servicio de couriers y controlar la capacidad disponible de la flota.

**Criterios de Aceptación:**
- [ ] Conexión a Base de Datos Cloud y entidad `CatalogService`.
- [ ] Endpoints CRUD para administrar servicios (`GET /api/catalog/services`, `POST`).
- [ ] `PUT /api/catalog/services/{id}` para reducción atómica de capacidad al aceptar un envío.

---
**Title:** [Backend] Configurar Publicador RabbitMQ en ms-rutaexpress-shipments
**Labels:** backend, devops
**Size:** S
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Integrar el envío asíncrono de eventos desde el microservicio de envíos hacia RabbitMQ.

**Criterios de Aceptación:**
- [ ] Al cambiar el estado de un envío (ej. "ACEPTADO"), publica mensaje a la cola correspondiente.
- [ ] Mensaje formateado bajo envelope común (`type`, `eventId`, `timestamp`, `traceId`, `correlationId`).
- [ ] Resiliencia: si RabbitMQ no está disponible, no se bloquea la transacción principal.

---
**Title:** [Backend] Crear microservicio ms-rutaexpress-notify (Consumidor RabbitMQ y DLQ)
**Labels:** backend, feature
**Size:** M
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Consumidor asíncrono para notificaciones al destinatario y tickets de picking para bodega.

**Criterios de Aceptación:**
- [ ] Servicio consume mensajes desde la cola `q.cmd.email`.
- [ ] Simulación de envío y logging de eventos.
- [ ] Mensajes fallidos son reenviados a la cola muerta (`q.cmd.email.dlq`) tras reintentos agotados.

---
**Title:** [Backend] Configurar Productor Kafka en ms-rutaexpress-shipments (Eventos Logísticos)
**Labels:** backend, devops
**Size:** S
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Publicar eventos inmutables de trazabilidad logística en tiempo real hacia Kafka.

**Criterios de Aceptación:**
- [ ] Productor Kafka configurado en `ms-rutaexpress-shipments`.
- [ ] Publica eventos logísticos al tópico `shipments.events` en cada cambio de estado.
- [ ] Serialización JSON y clave de partición basada en `shipmentId`.

---
**Title:** [Backend] Crear microservicio ms-rutaexpress-audit (Consumidor Kafka e Historial Inmutable)
**Labels:** backend, feature
**Size:** M
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Microservicio para persistir el timeline de trazabilidad y auditoría logística de forma desacoplada.

**Criterios de Aceptación:**
- [ ] Consumidor Kafka suscrito al tópico `shipments.events`.
- [ ] Registros insertados de forma inmutable en Base de Datos Cloud.
- [ ] Endpoint `GET /api/audit/shipments/{id}` para consultar historial de eventos.

---
**Title:** [Backend] Crear microservicio ms-rutaexpress-report (Consumidor Kafka y KPIs en tiempo real)
**Labels:** backend, feature
**Size:** M
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Microservicio para procesamiento analítico de métricas operacionales.

**Criterios de Aceptación:**
- [ ] Consumo de eventos desde Kafka y cálculo de métricas agregadas en memoria o base de datos.
- [ ] Endpoint `GET /api/report/kpis?range=last24h` (envíos/hora, lead time, estados activos).
- [ ] Endpoint `GET /api/report/top-services?range=last7d`.

---
**Title:** [Frontend] Dashboard de Operaciones y Métricas en Tiempo Real
**Labels:** frontend, feature
**Size:** M
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Vista en Angular para visualizar el panel de métricas y KPIs operacionales en tiempo real.

**Criterios de Aceptación:**
- [ ] Pantalla de Dashboard con tarjetas de KPIs (envíos activos, tiempos de entrega).
- [ ] Gráficos interactivos de volumen y servicios principales.
- [ ] Conexión segura hacia el BFF / API Gateway.

---
**Title:** [Infra] Despliegue Multi-Instancia en AWS (EC2 Apps, EC2 MQ, EC2 Kafka)
**Labels:** devops, infra
**Size:** L
**Milestone:** Sprint 2 - Asincronía y Analítica
**Body:**
Despliegue de la arquitectura completa en AWS con instancias EC2 dedicadas y Security Groups restringidos.

**Criterios de Aceptación:**
- [ ] Instancia `ec2-apps`: microservicios Spring Boot orquestados con `infra/apps/compose.yml`.
- [ ] Instancia `ec2-mq`: clúster RabbitMQ con `infra/mq/compose.yml`.
- [ ] Instancia `ec2-kafka`: Zookeeper, Kafka y Kafka UI con `infra/kafka/compose.yml`.
- [ ] Security Groups configurados para aislar la comunicación interna entre brokers y aplicaciones.

---
**Title:** [TechDebt] Estandarizar nombres de endpoints y recursos al español
**Labels:** task
**Size:** S
**Milestone:** Sprint 1 - Evaluación Parcial 1
**Body:**
Revisar y refactorizar los endpoints del BFF y futuros microservicios para asegurar que sigan el estándar en español (ej: /api/publico/salud, /api/administrador/panel, etc.).

**Criterios de Aceptación:**
- [ ] Refactorizar endpoints de prueba en ms-rutaexpress-bff a español.
- [ ] Asegurar que las rutas de negocio usen sustantivos en español (ej. /api/envios).
