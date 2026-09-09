# RutaExpress - Repositorio Central de Documentación y Gestión de Proyecto

Este repositorio actúa como el **Hub Central de Gestión y Documentación** del sistema **RutaExpress**.

Aquí se centralizan los **Issues del proyecto**, la documentación técnica, las pautas de evaluación y el seguimiento del trabajo mediante **GitHub Projects**.

---

## Repositorios del Sistema (Arquitectura Polirepo)

El código fuente del sistema está distribuido en repositorios independientes por microservicio/componente:

| Componente / Servicio | Repositorio GitHub | Descripción |
| :--- | :--- | :--- |
| **BFF (Backend For Frontend)** |  [ms-rutaexpress-bff](https://github.com/clmoralesl/ms-rutaexpress-bff) | Resource Server OAuth2 / RBAC en Spring Boot 3 |
| **Microservicio Envíos** |  [ms-rutaexpress-envios](https://github.com/clmoralesl/ms-rutaexpress-envios) | Servicio de Dominio para el ciclo de vida de envíos |
| **Frontend Web** |  [rutaexpress-frontend](https://github.com/clmoralesl/rutaexpress-frontend) | Aplicación Web en Angular con MSAL |
| **Hub Documentación** |  [RUTAEXPRESS_VGUARDIA_CMORALES](https://github.com/clmoralesl/RUTAEXPRESS_VGUARDIA_CMORALES) | Repositorio Central de Tareas y Documentación |

---

## Estructura del Repositorio de Documentación

- **`DOCS/backlog.md`**: Backlog maestro completo con los Issues del proyecto.
- **`DOCS/responsabilidades.md`**: Matriz de asignación de tareas.

---

## Variables de Entorno

Cada microservicio mantiene su propio archivo `.env` o `.env.example` en su respectivo repositorio adaptado a sus requerimientos específicos de infraestructura y bases de datos.
