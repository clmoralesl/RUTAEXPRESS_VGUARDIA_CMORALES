# Estado Actual del Proyecto y Contexto de Continuidad

**Fecha de actualización:** 14 de Septiembre, 2026  
**Propósito:** Este documento sirve como punto de partida (Hand-off) para iniciar una nueva conversación limpia en Antigravity y abordar el **Issue #9**.

---

## 1. Contexto General y Reglas Innegociables del Proyecto

### Arquitectura Polirepo
- **Repositorio Hub (Documentación / Infrastructure / Issues):** `RUTAEXPRESS_VGUARDIA_CMORALES`
- **Microservicios independientes:**
  - `ms-rutaexpress-bff` (Spring Boot 3.x, Resource Server OAuth2 con Azure AD, Puerto 8080)
  - `ms-rutaexpress-envios` (Spring Boot 3.x, Lógica de envíos, JPA hacia Oracle Cloud DB, Puerto 8081)
  - `rutaexpress-frontend` (Angular 20, Nginx Reverse Proxy / SPA, Puerto 4200 / 80)

### Reglas de Git y Desarrollo (.agents/AGENTS.md)
1. **Idioma de Commits:** Todos los mensajes de commit DEBEN redactarse en **español** siguiendo Commits Convencionales (`feat: ...`, `fix: ...`, `infra: ...`, `docs: ...`).
2. **Aprobación de Commits:** NUNCA realizar commits automáticos sin la aprobación explícita del usuario.
3. **Nombres en Español:** Todos los nombres de endpoints de la API y repositorios están obligatoriamente en **español** (ejemplo: `/api/publico/salud`, `/api/envios`, repositorio `ms-rutaexpress-envios`).
4. **Formato de Ramas:** Las ramas deben ser descriptivas en español y terminar obligatoriamente con el número del Issue (ejemplo: `infra/configurar-api-gateway-issue-9`).

---

## 2. Estado del Backlog (Sprint 1)

### 🔴 Issues Completados
- [x] **Issue #1:** `[Infra] Configurar App Registration en Azure AD`
- [x] **Issue #2:** `[Backend] Inicializar ms-rutaexpress-bff (Resource Server OAuth2)`
- [x] **Issue #3:** `[Backend] Configurar extracción de Roles y RBAC en ms-rutaexpress-bff`
- [x] **Issue #4:** `[Backend] Inicializar ms-rutaexpress-envios y conexión a BD Oracle`
- [x] **Issue #7:** `[Infra] Dockerizar microservicios y frontend`
- [x] **Issue #8:** `[Infra] Despliegue de microservicios en Amazon EKS y CI/CD` *(Completado y desplegado)*
  - Infraestructura creada con Terraform: VPC, NAT Gateway, Clúster EKS v1.30, Nodos EC2 y 3 repositorios en ECR.
  - Orquestación en Kubernetes: Manifiestos YAML en `infra/k8s/` con ConfigMaps, Secrets y montaje de Oracle Wallet.
  - CI/CD Automático: Workflows independientes de GitHub Actions configurados en la rama `deploy` de cada microservicio.
- [x] **Issue #28:** `[TechDebt] Estandarizar nombres de endpoints y recursos al español`
- [x] **Issue #29:** `[Infra/DB] Aprovisionar Oracle Cloud Database y Esquemas por Microservicio`

---

## 3. Próximo Issue a Resolver: Issue #9

- **ID del Issue:** `#9`
- **Título en GitHub:** `[Infra] Configurar AWS API Gateway (HTTP API + JWT Authorizer Azure AD)`
- **Asignado a:** Claudio (`clmoralesl`)
- **Nombre de la Rama a Crear:** `infra/configurar-api-gateway-issue-9` (en el repositorio hub `RUTAEXPRESS_VGUARDIA_CMORALES` o Terraform).

### Objetivos del Issue #9:
1. Crear un **AWS API Gateway (HTTP API)** usando Terraform o consola para exponer de forma centralizada la entrada al ecosistema EKS.
2. Configurar un **JWT Authorizer** integrado con Azure AD (vía Tenant ID y Client ID) para validar los tokens JWT en el borde (*Edge*) antes de que la petición llegue al clúster de EKS o BFF.
3. Enrutar las rutas públicas (`/api/publico/*`) y privadas (`/api/*`) hacia los LoadBalancers / Servicios de Kubernetes en EKS.

---

## 4. Instrucciones Directas para el Agente AI en la Nueva Conversación

> **Estimado Agente:**
> Al iniciar la conversación, lee este archivo (`DOCS/estado_actual.md`). Tu tarea principal es abordar el **Issue #9** (`AWS API Gateway + JWT Authorizer con Azure AD`).
> Pasos sugeridos:
> 1. Crear la rama `infra/configurar-api-gateway-issue-9`.
> 2. Analizar la infraestructura existente de Terraform en `infra/terraform/` y los servicios expuestos en EKS.
> 3. Redactar el plan de implementación para agregar los recursos de `aws_apigatewayv2_api`, `aws_apigatewayv2_authorizer` y las rutas correspondientes.
> 4. Solicitar aprobación del usuario antes de ejecutar los cambios.
