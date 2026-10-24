# Guia de Estandares, Git, Commits y Reglas de Desarrollo de RutaExpress

Este documento establece las reglas obligatorias de ingenieria de software, control de versiones y comunicacion tecnica para todos los desarrolladores y agentes de inteligencia artificial (Antigravity y Claude) que operan sobre el ecosistema RutaExpress.

---

## 1. Reglas de Git, Ramas y Flujo de Trabajo

### 1.1 Ramas por Issue
- Se debe trabajar de manera obligatoria en una rama independiente para cada Issue de GitHub.
- Nunca se debe desarrollar directamente sobre la rama `main`.
- **Formato estricto para el nombre de las ramas:**
  El nombre debe ser descriptivo, en minusculas, separado por guiones, redactado en idioma espanol, utilizando el prefijo convencional y terminando obligatoriamente con `-issue-N` al final:
  - Formato: `<tipo>/<descripcion-descriptiva-en-espanol>-issue-<numero>`
  - Ejemplos correctos:
    - `feat/generacion-codigo-normalizacion-direcciones-issue-57`
    - `fix/cors-preflight-rutas-api-gateway-issue-52`
    - `infra/dockerizar-servicios-issue-14`
    - `docs/actualizar-backlog-sprint-2-issue-30`

### 1.2 Regla de Aprobacion Previa de Commits
- **Prohibicion de commits automaticos:** Queda estrictamente prohibido realizar `git commit` o `git push` de forma automatica sin antes consultar y recibir la aprobacion formal y explicita del usuario.
- Siempre se debe presentar el resumen de los cambios y el `git diff` antes de solicitar la autorizacion para commitear.

### 1.3 Formato e Idioma de los Mensajes de Commit
- **Idioma Obligatorio:** Todos los mensajes de commit DEBEN redactarse en idioma **espanol**.
- **Estandar Conventional Commits:** Se debe utilizar el estandar de Commits Convencionales:
  - `feat(...)`: Nueva caracteristica o funcionalidad para el usuario.
  - `fix(...)`: Correccion de un error o defecto en el sistema.
  - `infra(...)`: Cambios en Terraform, Docker, AWS, scripts de arranque o configuracion de servidores.
  - `refactor(...)`: Modificaciones de codigo que no cambian el comportamiento externo.
  - `test(...)`: Incorporacion o correccion de pruebas unitarias o de integracion.
  - `docs(...)`: Cambios exclusivamente en documentacion tecnica o archivos markdown.
  - `chore(...)`: Tareas de mantenimiento de librerias o dependencias.
- **Estructura del Mensaje:**
  `tipo(alcance): descripcion clara y en minusculas en espanol (issue #N)`
  Ejemplo:
  `feat(envios): implementar generacion automatica de codigo institucional (issue #57)`

---

## 2. Reglas de Push y Plantilla Obligatoria de Pull Request (PR)

### 2.1 Requisitos para Realizar Push
- Solo se realiza `git push` a la rama remota despues de verificar que la compilacion local es exitosa (`mvn clean compile`, `npm run build`) y que no existen pruebas rotas.

### 2.2 Plantilla Obligatoria de Pull Request
Por cada push que se realice al considerar completado un Issue, el agente DEBE proporcionar obligatoriamente en el chat una plantilla formal de Pull Request en espanol, lista para copiar y pegar en GitHub, con la siguiente estructura minima:

```markdown
### Titulo del Pull Request
<tipo>(<alcance>): <descripcion en espanol> (Issue #N)

---

### Descripcion
<Explicacion tecnica clara y detallada de lo que resuelve este PR, componentes afectados y justificacion arquitectonica.>

---

### Criterios de Aceptacion Validados
- [ ] Criterio de aceptacion 1 cumplido y verificado.
- [ ] Criterio de aceptacion 2 cumplido y verificado.
- [ ] Compilacion limpia sin errores de sintaxis ni dependencias rotas.
- [ ] Pruebas unitarias ejecutadas satisfactoriamente.
```

---

## 3. Idioma y Nomenclatura del Proyecto

1. **Idioma de Endpoints:** Todos los nombres de las rutas y endpoints expuestos por los microservicios y el BFF deben estar obligatoriamente en **espanol**:
   - Correcto: `/api/envios`, `/api/catalogo/servicios`, `/api/publico/salud`, `/api/notificaciones/etiquetas`
   - Incorrecto: `/api/shipments`, `/api/catalog`, `/api/health`
2. **Nombres de Repositorios y Servicios:** Todos los componentes siguen el prefijo corporativo en espanol:
   - `ms-rutaexpress-envios`
   - `ms-rutaexpress-catalogo`
   - `ms-rutaexpress-notificaciones`
   - `ms-rutaexpress-auditoria`
   - `ms-rutaexpress-reportes`
   - `ms-rutaexpress-bff`
   - `rutaexpress-frontend`

---

## 4. Prohibicion Estricta de Emoticonos y Emojis

- Queda estrictamente prohibido el uso de cualquier tipo de emoticono o emoji (graficos o basados en texto) en:
  - Textos de respuesta en el chat.
  - Documentacion tecnica (`.md`, `.txt`, `.pdf`, etc.).
  - Mensajes de commit en Git.
  - Titulos y cuerpos de Pull Requests.
  - Codigo fuente (comentarios de clases, funciones o cadenas de texto).
- Toda la comunicacion y documentacion debe mantener un tono formal, sobrio, analitico y de nivel de ingenieria de software.

---

## 5. Detencion Temprana ante Bloqueos Tecnicos

- Ante cualquier bloqueo tecnico, fallo de conectividad de red, caida de servicios, problemas de certificados o errores de infraestructura, el proceso debe **detenerse inmediatamente**.
- Esta prohibido entrar en bucles de reintentos infructuosos, inventar configuraciones improvisadas o consumir tokens de forma innecesaria.
- Se debe reportar de inmediato la causa tecnica raiz exacta con logs de soporte y presentar opciones concretas al usuario para su decision.
