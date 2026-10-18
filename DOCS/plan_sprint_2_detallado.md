# Plan Detallado Sprint 2: RutaExpress - Plataforma SaaS de Última Milla

**Objetivo General:** Alcanzar el 90%+ de cobertura funcional del caso de estudio "Caso 3 RutaExpress", superando los requisitos académicos para transformar el sistema en un producto de nivel comercial, robusto, seguro y visualmente atractivo.
**Estrategia de Trabajo:** *Local-First Contract-Driven* (desarrollo desacoplado en local con Docker Compose para eliminar bloqueos entre Claudio y Valeska; las conexiones a AWS/Azure se ejecutan en la fase final de integración).

---

## Índice de Módulos e Issues

1. **Infraestructura Base y Asincronía Local (Claudio)**
   - Issue #17: Clúster RabbitMQ con Topología de 6 Colas y DLQ
   - Issue #18: Clúster Kafka, Zookeeper y Kafka UI
2. **Microservicios de Dominio y Mensajería (Claudio)**
   - Issue #19: ms-rutaexpress-catalogo (Flota, Capacidad y Tarifas)
   - Issue #20: Publicador RabbitMQ y Descuento de Capacidad en ms-rutaexpress-envios
   - Issue #21: ms-rutaexpress-notificaciones (Consumidor RabbitMQ, Tickets y DLQ)
   - Issue #22: Productor Kafka en ms-rutaexpress-envios (Event Sourcing Logístico)
   - Issue #23: ms-rutaexpress-auditoria (Consumidor Kafka, Timeline Inmutable)
   - Issue #24: ms-rutaexpress-reportes (Consumidor Kafka y Motor Analítico)
   - Issue #35: Enrutamiento y Agregación en ms-rutaexpress-bff
3. **Frontend, UI/UX y Experiencia de Usuario Comercial (Valeska)**
   - Issue #42: Landing Page Corporativa y Portal de Acceso Público (`/`)
   - Issue #43: Módulo de Rastreo Público con Stepper Visual y QR (`/rastreo`)
   - Issue #36: Módulo de Catálogo, Tarifador y Control de Capacidad (`/catalogo`)
   - Issue #37: Módulo de Auditoría con Timeline Interactivo (`/auditoria`)
   - Issue #38: Módulo de Reportería Analítica con Gráficos (`/reportes`)
   - Issue #25: Dashboard Operacional Dinámico por Rol (`/dashboard`)
4. **Propuestas de Valor "Dos Pasos Más Allá" (Diferenciadores Comerciales)**
   - Issue #40: Generación de Guía de Despacho y Etiqueta PDF con Código QR
   - Issue #44: Sistema Global de Feedback Visual, Notificaciones Toast y Skeletons
5. **Cierre, Seguridad, DevOps y Despliegue Cloud (Claudio & Valeska)**
   - Issue #39: Proxy Inverso Nginx con HTTPS y Delegación Limpia de CORS
   - Issue #26: Despliegue Multi-Instancia en AWS (EC2 Apps, EC2 MQ, EC2 Kafka)
   - Issue #41: Pruebas E2E de Calidad y Cierre de Evaluación 2

---

## BLOQUE 1: Infraestructura Base y Asincronía Local (Claudio)

### Issue #17: [Infra] Clúster RabbitMQ con Topología de 6 Colas y DLQ (infra/mq/compose.yml)
* **Responsable:** Claudio
* **Dependencias:** Ninguna (Inicio inmediato)
* **Objetivo:** Disponer localmente de un broker RabbitMQ listo para producción con Management UI, configurando la topología exacta exigida por el caso de negocio para procesamiento de tareas asíncronas y colas de reintento/muerte (Dead Letter Queue).
* **Criterios de Aceptación:**
  - [ ] Archivo `infra/mq/compose.yml` que levanta RabbitMQ con Management UI en puertos `5672` (AMQP) y `15672` (HTTP UI), con volumen de persistencia para colas y mensajes.
  - [ ] Script de aprovisionamiento o configuración inicial que declara los 3 Exchanges:
    - `cmd.direct` (Direct Exchange)
    - `cmd.topic` (Topic Exchange)
    - `cmd.dead.dlx` (Direct Exchange para Dead Letter Queues)
  - [ ] Creación y binding de las 6 colas especificadas en el caso:
    - `q.cmd.email` (Binding: `email.send` / `email.*`) con DLQ `q.cmd.email.dlq`
    - `q.cmd.warehouse` (Binding: `warehouse.ticket` / `warehouse.#`) con DLQ `q.cmd.warehouse.dlq`
    - `q.cmd.label` (Binding: `label.gen` / `label.*`) con DLQ `q.cmd.label.dlq`
  - [ ] Argumentos DLQ configurados (`x-dead-letter-exchange: cmd.dead.dlx`, `x-message-ttl` y `x-max-length`).
  - [ ] Verificación desde RabbitMQ Management UI de que las colas y exchanges existen y procesan mensajes de prueba.

---

### Issue #18: [Infra] Clúster Kafka, Zookeeper y Kafka UI (infra/kafka/compose.yml)
* **Responsable:** Claudio
* **Dependencias:** Ninguna (Inicio inmediato)
* **Objetivo:** Disponer de una plataforma de streaming de eventos distribuida para alimentar en tiempo real los módulos de auditoría y reportes analíticos sin bloquear la transacción principal del negocio.
* **Criterios de Aceptación:**
  - [ ] Archivo `infra/kafka/compose.yml` que levanta Zookeeper, Apache Kafka (puerto `9092`) y Kafka UI (puerto `8085` o similar) con persistencia de datos.
  - [ ] Script o inicializador automático de los tópicos requeridos por el caso:
    - `shipments.events` (o `envios.eventos`): Tópico troncal de eventos de ciclo de vida (3 particiones, retención 7 días).
    - `audit.timeline`: Tópico especializado de auditoría inmutable (3 particiones, política `compact,delete`).
    - `*.DLT`: Tópicos Dead Letter Topic para mensajes con error irrecuperable de deserialización o procesamiento.
  - [ ] Verificación desde Kafka UI: creación, visualización de particiones y capacidad de inspección de mensajes JSON.

---

## BLOQUE 2: Microservicios de Dominio y Mensajería (Claudio)

### Issue #19: [Backend] Inicializar ms-rutaexpress-catalogo (Flota, Capacidad y Tarifas)
* **Responsable:** Claudio
* **Dependencias:** Conexión a Oracle Cloud esquema `USER_CATALOGO`
* **Objetivo:** Administrar los tipos de servicio de última milla (Express, Estándar, Mismo Día, Carga Pesada), tarifas base por kilómetro/peso y el control atómico de capacidad vehicular de los 20 couriers PyME.
* **Criterios de Aceptación:**
  - [ ] Microservicio Spring Boot 3.x Java 17 con conexión al esquema `USER_CATALOGO`.
  - [ ] Entidad `ServicioCatalogo`: ID, código, nombre, descripción, tipoVehiculo, tarifaBase, precioPorKg, capacidadMaximaDiaria, capacidadDisponible, activo.
  - [ ] `GET /api/catalogo/servicios`: Retorna lista de servicios activos con tarifas y cupos disponibles.
  - [ ] `POST /api/catalogo/servicios`: Creación de nuevos servicios logísticos (restringido a `ROLE_ADMIN`).
  - [ ] `PUT /api/catalogo/servicios/{id}`: Actualización de tarifas y capacidad máxima.
  - [ ] `PATCH /api/catalogo/servicios/{id}/descontar-capacidad`: Endpoint atómico y thread-safe que reduce en 1 la capacidad disponible cuando se acepta un envío. Si la capacidad es 0, rechaza con HTTP 409 Conflict ("Capacidad de flota agotada").
  - [ ] Endpoint de salud `/actuator/health` y `/api/publico/salud`.

---

### Issue #20: [Backend] Integrar Publicador RabbitMQ y Descuento de Capacidad en ms-rutaexpress-envios
* **Responsable:** Claudio
* **Dependencias:** Issue #17 (RabbitMQ), Issue #19 (Catálogo)
* **Objetivo:** Automatizar la publicación asíncrona de comandos de correo/bodega y coordinar la reducción de capacidad de flota cada vez que un envío avanza de estado.
* **Criterios de Aceptación:**
  - [ ] Envelope estándar para mensajes RabbitMQ: `tipo`, `eventoId`, `timestamp`, `traceId`, `correlationId`, `datos`.
  - [ ] Al cambiar el estado a `ACEPTADO`:
    1. Invoca a `ms-rutaexpress-catalogo` para descontar cupo de flota de forma atómica.
    2. Publica mensaje a `q.cmd.email` para avisar al cliente que su paquete fue recibido.
    3. Publica mensaje a `q.cmd.warehouse` con la información del paquete para generar el ticket de picking en bodega.
  - [ ] Al cambiar el estado a `EN_RUTA` o `ENTREGADO`: publica eventos correspondientes a `q.cmd.email`.
  - [ ] Mecanismo de resiliencia: si RabbitMQ experimenta una interrupción transitoria, el guardado en base de datos de envíos no colapsa (manejo de excepciones controlado).

---

### Issue #21: [Backend] Inicializar ms-rutaexpress-notificaciones (Consumidor RabbitMQ, Tickets y DLQ)
* **Responsable:** Claudio
* **Dependencias:** Issue #17 (RabbitMQ)
* **Objetivo:** Microservicio desacoplado que escucha las colas de trabajo para procesar despachos de correos/notificaciones y emitir tickets de bodega sin bloquear al usuario.
* **Criterios de Aceptación:**
  - [ ] Microservicio Spring Boot que implementa `@RabbitListener` escuchando `q.cmd.email`, `q.cmd.warehouse` y `q.cmd.label`.
  - [ ] Simulación realista de envío de correo/webpush con logs enriquecidos y estructurados.
  - [ ] Generación de tickets de picking en formato JSON estructurado listo para impresión térmica de bodega.
  - [ ] Manejo explícito de confirmación (ACK/NACK con `requeue=false` ante errores fatales) redirigiendo automáticamente a las colas DLQ (`q.cmd.email.dlq`, etc.) tras 3 reintentos fallidos.
  - [ ] Endpoint de monitoreo de estado de colas y estadísticas de mensajes procesados.

---

### Issue #22: [Backend] Integrar Productor Kafka en ms-rutaexpress-envios (Event Sourcing Logístico)
* **Responsable:** Claudio
* **Dependencias:** Issue #18 (Kafka)
* **Objetivo:** Transformar el ciclo de vida de los envíos en un stream inmutable de eventos que transmita cada acción a los consumidores de auditoría y analítica en tiempo real.
* **Criterios de Aceptación:**
  - [ ] Configuración de `KafkaTemplate` con serializador JSON en `ms-rutaexpress-envios`.
  - [ ] Particionamiento por clave lógica: `key = envioId.toString()` para garantizar orden secuencial de eventos por envío.
  - [ ] En cada cambio de estado (`CREADO`, `ACEPTADO`, `EN_BODEGA`, `EN_RUTA`, `ENTREGADO`, `CANCELADO`), se emite un evento estructurado al tópico `shipments.events`:
    - `eventoId`, `envioId`, `estadoAnterior`, `estadoNuevo`, `usuarioEmail`, `usuarioRol`, `timestamp`, `detalles`.
  - [ ] Resiliencia: timeouts de Kafka configurados para que la falla del broker no impida la respuesta HTTP inmediata al cliente.

---

### Issue #23: [Backend] Inicializar ms-rutaexpress-auditoria (Consumidor Kafka, Timeline Inmutable)
* **Responsable:** Claudio
* **Dependencias:** Issue #18 (Kafka), Conexión a Oracle Cloud esquema `USER_AUDITORIA`
* **Objetivo:** Almacenar de forma inmutable el historial completo de quién, qué, cuándo y desde dónde se manipuló cada paquete, garantizando trazabilidad legal y operativa.
* **Criterios de Aceptación:**
  - [ ] Microservicio Spring Boot con `@KafkaListener(topics = "shipments.events", groupId = "auditoria-group")`.
  - [ ] Persistencia en esquema `USER_AUDITORIA` (Tabla `HISTORIAL_AUDITORIA` con índices en `envio_id`, `usuario_email` y `fecha_evento`).
  - [ ] La tabla es **estrictamente de solo lectura / inserción** (no existen endpoints de UPDATE ni DELETE).
  - [ ] Endpoint `GET /api/auditoria/envios/{id}`: Retorna el timeline cronológico completo de un envío específico.
  - [ ] Endpoint `GET /api/auditoria/eventos`: Consulta paginada con filtros por usuario, fechaDesde, fechaHasta y tipo de acción (restringido a `ROLE_ADMIN` y `ROLE_AUDITOR`).

---

### Issue #24: [Backend] Inicializar ms-rutaexpress-reportes (Consumidor Kafka y Motor Analítico)
* **Responsable:** Claudio
* **Dependencias:** Issue #18 (Kafka)
* **Objetivo:** Calcular métricas operacionales agregadas en tiempo real sin sobrecargar la base de datos transaccional de envíos.
* **Criterios de Aceptación:**
  - [ ] Microservicio Spring Boot que consume de `shipments.events` para mantener acumuladores en memoria o base de datos analítica.
  - [ ] Cálculo de **Lead Time promedio** (tiempo transcurrido entre creación y entrega efectiva).
  - [ ] Cálculo de **Envíos por hora** (volumen en ventanas de tiempo).
  - [ ] Conteo de **Envíos por estado activo** (cuántos en bodega, cuántos en ruta).
  - [ ] `GET /api/reportes/kpis?rango=ultimas24h`: Retorna resumen ejecutivo con métricas operacionales clave.
  - [ ] `GET /api/reportes/top-servicios?rango=ultimos7dias`: Ranking de servicios más solicitados de la red.
  - [ ] `GET /api/reportes/rendimiento-couriers`: Tasa de éxito y entregas a tiempo por operador.

---

### Issue #35: [Backend] Orquestación y Agregación en ms-rutaexpress-bff
* **Responsable:** Claudio
* **Dependencias:** Issues #19, #23, #24
* **Objetivo:** Centralizar el enrutamiento seguro hacia todos los nuevos microservicios a través del BFF, aplicando RBAC y protegiendo la red privada de Kubernetes.
* **Criterios de Aceptación:**
  - [ ] Enrutamiento seguro para `/api/bff/catalogo/**` hacia `ms-rutaexpress-catalogo`.
  - [ ] Enrutamiento seguro para `/api/bff/auditoria/**` hacia `ms-rutaexpress-auditoria`.
  - [ ] Enrutamiento seguro para `/api/bff/reportes/**` hacia `ms-rutaexpress-reportes`.
  - [ ] Reenvío automático del Token JWT (Token Relay) validando roles con `@PreAuthorize`.
  - [ ] Manejo de Fallback amigable: si el servicio de analítica no responde, devuelve HTTP 503 con formato JSON estándar sin que la aplicación Angular colapse.

---

## BLOQUE 3: Frontend, UI/UX y Experiencia de Usuario Comercial (Valeska)

### Issue #42: [Frontend] Landing Page Corporativa y Portal de Acceso Público (/)
* **Responsable:** Valeska
* **Dependencias:** Ninguna (Inicio inmediato con mock)
* **Objetivo:** Proveer una fachada comercial de alto impacto visual que demuestre que RutaExpress es un producto real listo para el mercado, permitiendo rastreo directo y login empresarial.
* **Criterios de Aceptación:**
  - [ ] Portada moderna con banner principal (Hero section), logotipo oficial, propuesta de valor de la red de 20 couriers y diseño 100% responsivo.
  - [ ] **Buscador Rápido de Envíos:** Input principal en el centro de la pantalla que recibe un código de seguimiento y redirige instantáneamente a `/rastreo?codigo=...`.
  - [ ] Sección de servicios destacados (Express, Mismo Día, Estándar) con información de tarifas orientativas.
  - [ ] Botón de "Acceso Corporativo" estilizado con logotipo oficial de Microsoft para login vía Azure AD / MSAL.
  - [ ] Footer corporativo con datos de soporte, estado operacional y enlaces institucionales.

---

### Issue #43: [Frontend] Módulo de Rastreo Público con Stepper Visual y QR (/rastreo)
* **Responsable:** Valeska
* **Dependencias:** Issue #36 (Landing)
* **Objetivo:** Ofrecer una experiencia de seguimiento de paquetes de nivel consumidor (estilo FedEx/Starken), 100% pública (sin requerir login).
* **Criterios de Aceptación:**
  - [ ] Ruta `/rastreo` y `/rastreo/:codigo` pública (excluida del `MsalGuard`).
  - [ ] **Stepper Visual de Progreso:** Indicador dinámico por pasos:
    - *1. Creado* ➔ *2. Aceptado* ➔ *3. En Bodega* ➔ *4. En Ruta* ➔ *5. Entregado* (o badge de *Cancelado*).
  - [ ] Tarjeta de detalles del envío: ciudad origen, ciudad destino, fecha estimada de entrega, servicio contratado y courier asignado.
  - [ ] Vista limpia y sin datos confidenciales (oculta precios y datos sensibles de facturación).
  - [ ] Manejo de errores visual si el código de tracking no existe con opción de intentar nuevamente.

---

### Issue #36: [Frontend] Módulo de Catálogo, Tarifador y Control de Capacidad (/catalogo)
* **Responsable:** Valeska
* **Dependencias:** Issue #19 (Backend Catálogo) o JSON Mock local
* **Objetivo:** Interfaz visual para que el Administrador gestione los servicios logísticos de la red y supervise la capacidad disponible de la flota en tiempo real.
* **Criterios de Aceptación:**
  - [ ] Tabla interactiva de servicios con badges de estado (Activo / Inactivo).
  - [ ] **Indicador visual de capacidad vehicular:** Barra de progreso (porcentaje de cupos utilizados vs disponibles) con alerta visual (amarillo/rojo) si la capacidad baja del 20%.
  - [ ] Modal reactivo para crear/editar servicios y tarifas base por kilogramo.
  - [ ] **Tarifador rápido (Calculadora de Envíos):** Componente interactivo donde el usuario ingresa peso y dimensiones y calcula el costo estimado al instante.
  - [ ] Control de permisos: solo usuarios con `ROLE_ADMIN` pueden modificar datos; otros roles solo lectura.

---

### Issue #37: [Frontend] Módulo de Auditoría con Timeline Interactivo (/auditoria)
* **Responsable:** Valeska
* **Dependencias:** Issue #23 (Backend Auditoría) o JSON Mock local
* **Objetivo:** Pantalla de cumplimiento y trazabilidad para el Administrador y Auditor, mostrando el historial de eventos con diseño de línea de tiempo cronológica.
* **Criterios de Aceptación:**
  - [ ] Filtros avanzados de búsqueda: por ID de envío, rango de fechas y correo del operador.
  - [ ] **Línea de Tiempo (Timeline Component):** Lista cronológica con iconos por tipo de evento (creación, cambio de bodega, salida a ruta, firma de entrega).
  - [ ] Despliegue de metadatos de auditoría: usuario ejecutor, rol, dirección IP o canal de origen, y timestamp legible.
  - [ ] Badge comparativo visual que muestra el "Estado anterior" versus el "Nuevo estado".
  - [ ] Ruta protegida por `MsalGuard` restringida a `ROLE_ADMIN` y `ROLE_AUDITOR`.

---

### Issue #38: [Frontend] Módulo de Reportería Analítica con Gráficos (/reportes)
* **Responsable:** Valeska
* **Dependencias:** Issue #24 (Backend Reportes) o JSON Mock local
* **Objetivo:** Panel analítico de inteligencia operacional para toma de decisiones gerenciales mediante visualizaciones de datos interactivas.
* **Criterios de Aceptación:**
  - [ ] Integración de librería de gráficos (Chart.js, ngx-charts o ApexCharts).
  - [ ] **Gráfico 1 (Líneas/Barras):** Volumen de envíos por hora / últimas 24 horas.
  - [ ] **Gráfico 2 (Dona/Pastel):** Distribución de envíos por estado activo (en bodega vs en ruta vs entregados).
  - [ ] **Gráfico 3 (Barras horizontales):** Top de servicios más solicitados de la red.
  - [ ] Tarjetas KPI destacadas en la parte superior: Lead Time Promedio, Tasa de Cumplimiento (%) y Total Facturado/Envíos activos.
  - [ ] Selector de rango de tiempo (Últimas 24h, Últimos 7 días, Último mes).

---

### Issue #25: [Frontend] Dashboard Operacional Dinámico por Rol (/dashboard)
* **Responsable:** Valeska
* **Dependencias:** Issues #31, #34
* **Objetivo:** Pantalla de aterrizaje post-login que adapta su contenido y accesos según el rol de la persona autenticada.
* **Criterios de Aceptación:**
  - [ ] **Vista Admin:** Tarjetas de resumen ejecutivo de la red, accesos rápidos a gestión de capacidad y botón directo a reportes.
  - [ ] **Vista Despachador:** Bandeja de envíos pendientes de preparación, lista de envíos en bodega y accesos para armar hoja de ruta.
  - [ ] **Vista Cliente:** Resumen de sus últimos envíos realizados con accesos de un clic a la creación de nuevo envío y estado actual.
  - [ ] Saludo personalizado dinámico: "Bienvenido, {nombre}" extrayendo el claim del token MSAL.

---

## BLOQUE 4: Propuestas de Valor "Dos Pasos Más Allá" (Diferenciadores)

### Issue #40: [Feature] Generación de Guía de Despacho y Etiqueta PDF con Código QR
* **Responsable:** Claudio (Backend) y Valeska (Frontend)
* **Dependencias:** Issue #20 (RabbitMQ label), Issue #14 (Listado Envíos)
* **Objetivo:** Permitir la descarga e impresión física de etiquetas térmicas estándar con código QR para los paquetes, simulando la operación real de una bodega logística.
* **Criterios de Aceptación:**
  - [ ] Botón "Imprimir Etiqueta / Guía" en la vista de detalle de cada envío.
  - [ ] Generación de etiqueta en formato estándar (ej. 10x15 cm para impresión térmica) con:
    - Código de barras o QR que contiene la URL directa de seguimiento público (`https://.../rastreo/:codigo`).
    - Datos del remitente, destinatario, dirección y servicio contratado.
  - [ ] El microservicio procesa la solicitud mediante la cola `q.cmd.label` en RabbitMQ.
  - [ ] Modal de previsualización e impresión directa en el navegador (`window.print` o visor PDF embebido).

---

### Issue #44: [Frontend] Sistema Global de Feedback Visual, Toasts y Skeletons
* **Responsable:** Valeska
* **Dependencias:** Vistas frontend
* **Objetivo:** Elevar radicalmente la percepción de calidad del producto, erradicando los `alert()` y mensajes crudos del navegador por componentes UI modernos.
* **Criterios de Aceptación:**
  - [ ] Servicio centralizado de notificaciones Toast (flotantes en esquina) para éxitos, advertencias y errores de red.
  - [ ] Modales de confirmación con diseño corporativo para acciones destructivas o cambios de estado críticos (ej: Cancelar envío).
  - [ ] **Loading Skeletons (animaciones de carga con siluetas):** Reemplazar tablas vacías por siluetas animadas mientras viaja la respuesta HTTP.
  - [ ] Manejo visual amigable de estados vacíos ("Aún no tienes envíos registrados").

---

## BLOQUE 5: Cierre, Seguridad, DevOps y Cloud (Claudio & Valeska)

### Issue #39: [DevOps] Proxy Inverso Nginx con HTTPS para Frontend y Backend (Resolver MSAL sin flags y CORS)
* **Responsable:** Claudio
* **Dependencias:** Dockerfiles y compose local funcional
* **Objetivo:** Resolver definitivamente la observación del profesor respecto al error `crypto_nonexistent` de MSAL y preflights CORS, usando Nginx con certificado SSL como fachada unificada.
* **Criterios de Aceptación:**
  - [ ] Configuración de Nginx en contenedor (`infra/nginx/nginx.conf`) que expone el puerto `443` (HTTPS) con certificado SSL (autofirmado o Let's Encrypt).
  - [ ] Enrutamiento unificado:
    - `https://localhost/` ➔ Sirve la aplicación Angular compilada.
    - `https://localhost/api/` ➔ Redirige internamente al BFF (`ms-rutaexpress-bff:8080`).
  - [ ] Al estar bajo HTTPS, el navegador otorga contexto seguro y la librería MSAL Angular opera sin requerir `chrome://flags` ni `edge://flags`.
  - [ ] Manejo centralizado de cabeceras CORS en Nginx, respondiendo de inmediato a los preflights `OPTIONS` con HTTP 204 sin tocar el backend.

---

### Issue #26: [Infra] Despliegue Multi-Instancia en AWS (EC2 Apps, EC2 MQ, EC2 Kafka)
* **Responsable:** Claudio
* **Dependencias:** Todos los microservicios y compose funcionales en local
* **Objetivo:** Trasladar la arquitectura contenerizada validada en local hacia la nube de AWS con instancias segmentadas por responsabilidad y Security Groups estrictos.
* **Criterios de Aceptación:**
  - [ ] Instancia `ec2-apps`: Corre el frontend (Nginx), BFF y microservicios de dominio.
  - [ ] Instancia `ec2-mq`: Corre el clúster de RabbitMQ con colas y DLQ.
  - [ ] Instancia `ec2-kafka`: Corre Zookeeper, Kafka y Kafka UI.
  - [ ] Security Groups de AWS configurados para permitir solo comunicación interna entre instancias en los puertos AMQP (5672) y Kafka (9092).
  - [ ] Pruebas de conectividad y logs verdes en la nube.

---

### Issue #41: [QA] Pruebas de Integración E2E y Suite de Calidad para Sprint 2 (Evaluación 2)
* **Responsable:** Ambos
* **Dependencias:** Todos los issues anteriores completados
* **Objetivo:** Validación integral de todos los flujos de negocio y preparación del guion de defensa para la presentación.
* **Criterios de Aceptación:**
  - [ ] Verificación de flujo E2E 1: Creación de envío ➔ Aceptación ➔ Descuento de cupo en catálogo ➔ Emisión de correo en RabbitMQ ➔ Ticket de bodega ➔ Evento en Kafka.
  - [ ] Verificación de flujo E2E 2: Inspección de timeline en pantalla de Auditoría y reflejo de métricas en pantalla de Reportes en tiempo real.
  - [ ] Verificación de flujo E2E 3: Rastreo público desde la Landing Page usando el código de seguimiento sin login.
  - [ ] Verificación de login corporativo fluido bajo HTTPS sin advertencias de navegador.
  - [ ] Documento de evidencias y capturas de prueba compilado en la carpeta `DOCS`.
