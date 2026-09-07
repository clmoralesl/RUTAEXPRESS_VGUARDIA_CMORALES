# Backlog RutaExpress - Desglose de Tareas

Este documento contiene el backlog del proyecto desglosado en tareas pequeñas y modulares, separadas por Sprints. 
Está diseñado para evitar conflictos de integración ("merge conflicts") y enfocar el esfuerzo en lo que requiere la pauta de evaluación.
El formato utilizado permite que un script pueda leer este archivo y generar los Issues automáticamente en GitHub (separando cada Issue con `---`).

## Sprint 1 - Evaluación Parcial 1 (Seguridad, BFF y CRUD Envíos)
*Objetivo: Cumplir con el 100% de la pauta de evaluación N°1, logrando un flujo de autenticación seguro y dos pantallas funcionales conectadas a la base de datos.*

---
**Title:** [Infra] Configurar App Registration en Azure AD
**Labels:** security, devops
**Size:** S
**Body:**
Configurar el entorno de identidad (IDaaS) en Azure Active Directory para el login corporativo.

**Criterios de Aceptación:**
- [ ] La aplicación "RutaExpress" existe en Azure AD.
- [ ] Se obtienen las credenciales (`clientId` y `tenantId`).
- [ ] La URL de redirección (ej. `http://localhost:4200`) está configurada para el Frontend.
- [ ] La API (App ID URI) está expuesta con los scopes correspondientes (`api://<API_CLIENT_ID>`).
- [ ] Las credenciales de desarrollo están documentadas en el README.

---
**Title:** [Frontend] Inicializar proyecto Angular y estructura base
**Labels:** frontend, task
**Size:** S
**Body:**
Crear la aplicación Angular vacía (frontend-rutaexpress) que servirá de base.

**Criterios de Aceptación:**
- [ ] El proyecto compila correctamente con `ng serve`.
- [ ] La estructura inicial existe dentro de la carpeta `FRONTEND`.
- [ ] El archivo `.gitignore` incluye la exclusión de `node_modules` y directorios de compilación.

---
**Title:** [Backend] Inicializar ms-rutaexpress-bff (Backend For Frontend)
**Labels:** backend, security, task
**Size:** M
**Body:**
Crear el microservicio proxy/BFF en Spring Boot que valida los tokens y rutea al dominio.

**Criterios de Aceptación:**
- [ ] El proyecto Spring Boot levanta correctamente en un puerto definido (ej. 8080).
- [ ] Se valida que el token recibido desde el frontend pertenece al `issuer-uri` correcto de Azure AD.
- [ ] Retorna HTTP 401 si se intenta consumir un endpoint protegido sin token o con token inválido.

---
**Title:** [Frontend] Integrar MSAL y flujo de Login
**Labels:** frontend, security
**Size:** M
**Body:**
*Depende de: [Infra] Configurar App Registration en Azure AD*
Configurar la autenticación utilizando la librería oficial de Microsoft.

**Criterios de Aceptación:**
- [ ] El botón "Iniciar sesión con Microsoft" redirige correctamente al login de Azure.
- [ ] Tras el login exitoso, la aplicación captura y almacena el Token JWT (`access_token`).
- [ ] El usuario es redirigido a una página privada inicial (ej. `/dashboard`).

---
**Title:** [Frontend] Implementar Guards e Interceptor MSAL
**Labels:** frontend, security
**Size:** S
**Body:**
*Depende de: [Frontend] Integrar MSAL y flujo de Login*
Asegurar las rutas en el frontend y habilitar la comunicación segura con el backend.

**Criterios de Aceptación:**
- [ ] `MsalGuard` bloquea el acceso a rutas privadas a usuarios no autenticados, redirigiéndolos al login.
- [ ] `MsalInterceptor` inyecta correctamente el encabezado `Authorization: Bearer <token>` en todas las peticiones HTTP que vayan a `/api/*`.

---
**Title:** [Backend] Configurar extracción de Roles en ms-rutaexpress-bff
**Labels:** backend, security
**Size:** S
**Body:**
*Depende de: [Backend] Inicializar ms-rutaexpress-bff*
Parsear los claims del JWT para manejar la autorización basada en roles (RBAC).

**Criterios de Aceptación:**
- [ ] El `JwtAuthenticationConverter` extrae los roles y los mapea a "ROLE_ADMIN", "ROLE_DESPACHADOR", etc.
- [ ] Un endpoint de prueba (ej. `/api/test-admin`) retorna HTTP 403 si el token pertenece a un usuario Cliente.

---
**Title:** [Frontend] Maquetación de Layout Principal (Navbar y Sidebar)
**Labels:** frontend, feature
**Size:** S
**Body:**
Crear la estructura visual que encapsulará las diferentes vistas del sistema.

**Criterios de Aceptación:**
- [ ] La barra de navegación muestra el nombre del usuario y su rol extraídos del token JWT.
- [ ] Existe un botón funcional de "Cerrar Sesión" que invalida el estado en MSAL.
- [ ] El diseño base es responsivo y se renderiza correctamente (sin errores en consola).

---
**Title:** [Backend] Inicializar ms-rutaexpress-shipments (Envíos) - Base de Datos
**Labels:** backend, task
**Size:** S
**Body:**
Crear el microservicio de negocio encargado del ciclo de vida de los envíos.

**Criterios de Aceptación:**
- [ ] El proyecto conecta exitosamente a la base de datos Oracle configurada.
- [ ] JPA genera correctamente la tabla para la entidad `Shipment`.
- [ ] El repositorio Spring Data `ShipmentRepository` está implementado.

---
**Title:** [Backend] CRUD Básico ms-rutaexpress-shipments
**Labels:** backend, feature
**Size:** M
**Body:**
*Depende de: [Backend] Inicializar ms-rutaexpress-shipments*
Habilitar las operaciones básicas para los envíos.

**Criterios de Aceptación:**
- [ ] `POST /api/shipments` crea el envío en estado "CREADO" y retorna HTTP 201 con el id.
- [ ] `GET /api/shipments/{id}` retorna HTTP 200 con el detalle del envío o HTTP 404 si no existe.
- [ ] `GET /api/shipments` retorna una lista paginada o filtrada de los envíos.

---
**Title:** [Backend] Actualización de Estados en ms-rutaexpress-shipments
**Labels:** backend, feature
**Size:** S
**Body:**
*Depende de: [Backend] CRUD Básico ms-rutaexpress-shipments*
Habilitar la progresión del ciclo de vida de los envíos.

**Criterios de Aceptación:**
- [ ] `PUT /api/shipments/{id}/status` permite actualizar el estado y retorna HTTP 200.
- [ ] El sistema rechaza con HTTP 400 (Bad Request) transiciones inválidas (Ej: CREADO directo a EN_RUTA).
- [ ] Se valida la máquina de estados: CREADO -> ACEPTADO -> EN_BODEGA -> EN_RUTA -> ENTREGADO.

---
**Title:** [Frontend] Vista de Listado de Envíos
**Labels:** frontend, feature
**Size:** M
**Body:**
*Depende de: [Frontend] Implementar Guards e Interceptor MSAL*
Mostrar los envíos llamando al backend protegido.

**Criterios de Aceptación:**
- [ ] La tabla de envíos renderiza los datos correctos consumiendo el BFF.
- [ ] El token de MSAL es adjuntado automáticamente.
- [ ] Se maneja visualmente el estado de carga y el estado vacío (si no hay envíos).

---
**Title:** [Frontend] Vista de Creación de Envíos y Cambio de Estado
**Labels:** frontend, feature
**Size:** M
**Body:**
*Depende de: [Frontend] Vista de Listado de Envíos*
Interacción con el negocio (Crear y avanzar estados).

**Criterios de Aceptación:**
- [ ] El formulario para crear envío captura todos los campos obligatorios antes de enviar (validación frontend).
- [ ] La tabla incluye una acción (botón/dropdown) visible para Despachadores/Admins que permite avanzar el estado.
- [ ] Si el backend retorna error de validación de máquina de estados, se muestra una alerta amigable al usuario.


## Sprint 2 - Asincronía, Analítica e Infraestructura Avanzada
*Objetivo: Integrar RabbitMQ, Kafka y despliegue final en la nube (AWS).*

---
**Title:** [Infra] Crear esqueleto de Docker Compose (RabbitMQ y Kafka)
**Labels:** devops, task
**Size:** S
**Body:**
Crear los archivos base para levantar la infraestructura de mensajería en el entorno local (y posteriormente en AWS EC2).

**Criterios de Aceptación:**
- [ ] El archivo `infra/mq/compose.yml` levanta RabbitMQ con Management UI accesible en puerto 15672.
- [ ] El archivo `infra/kafka/compose.yml` levanta Zookeeper y Kafka en el puerto 9092.
- [ ] Los contenedores levantan sin errores y persisten los datos en volúmenes locales.

---
**Title:** [Backend] Inicializar ms-rutaexpress-catalog (Catálogo y Capacidad)
**Labels:** backend, feature
**Size:** M
**Body:**
Microservicio para administrar tipos de servicio y capacidad de flota de cada courier.

**Criterios de Aceptación:**
- [ ] Conexión a Oracle DB exitosa.
- [ ] Endpoints básicos CRUD para gestionar `CatalogService`.
- [ ] `PUT /api/catalog/services/{id}` permite reducir la capacidad disponible. (Se usará al aceptar un envío).

---
**Title:** [Backend] Configurar Publicador RabbitMQ en ms-rutaexpress-shipments
**Labels:** backend, devops
**Size:** S
**Body:**
*Depende de: [Infra] Crear esqueleto de Docker Compose (RabbitMQ)*
Integrar el envío asíncrono de eventos al cambiar de estado.

**Criterios de Aceptación:**
- [ ] Al avanzar un envío a estado "ACEPTADO", se envía un mensaje a la cola `q.cmd.email`.
- [ ] El mensaje enviado usa un formato común ("envelope") incluyendo `eventId` y `timestamp`.
- [ ] Si RabbitMQ está caído, la aplicación maneja el error (logging) sin botar el proceso principal.

---
**Title:** [Backend] Crear microservicio ms-rutaexpress-notify
**Labels:** backend, feature
**Size:** M
**Body:**
*Depende de: [Backend] Configurar Publicador RabbitMQ en ms-rutaexpress-shipments*
Consumidor asíncrono para notificaciones al destinatario o a bodega.

**Criterios de Aceptación:**
- [ ] El servicio consume exitosamente mensajes de la cola `q.cmd.email`.
- [ ] Se imprime en log (simulando envío real) la información del correo enviado.
- [ ] Los mensajes fallidos son ruteados correctamente a la `q.cmd.email.dlq` tras reintentos fallidos.

---
**Title:** [Backend] Inicializar ms-rutaexpress-audit (Auditoría Kafka)
**Labels:** backend, devops
**Size:** L
**Body:**
Microservicio para almacenar el timeline de trazabilidad logística de forma no bloqueante.

**Criterios de Aceptación:**
- [ ] El servicio se conecta al broker de Kafka.
- [ ] Consume correctamente mensajes desde el tópico `shipments.events`.
- [ ] Los eventos consumidos se insertan como registros inmutables en la base de datos Oracle.
- [ ] Endpoint `GET /api/audit` expone la información y es de solo lectura.

---
**Title:** [Infra] AWS API Gateway (Configuración)
**Labels:** devops, security
**Size:** M
**Body:**
Crear la protección perimetral del sistema a desplegar en AWS.

**Criterios de Aceptación:**
- [ ] El HTTP API está creado en API Gateway.
- [ ] El JWT Authorizer valida exitosamente los tokens de Azure AD de RutaExpress.
- [ ] Las peticiones bloqueadas retornan HTTP 401 antes de llegar a la instancia EC2.
- [ ] Las peticiones válidas son enrutadas al `ms-rutaexpress-bff`.
