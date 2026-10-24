# Directorio de Trabajo Colaborativo Dual: Antigravity & Claude

Este directorio centraliza todos los documentos, registros de relevo, archivos de diferencias (diffs), dictámenes de arquitectura/seguridad y normativas de desarrollo que rigen el trabajo conjunto entre los agentes **Antigravity** (implementador y DevOps) y **Claude** (arquitecto de software y auditor de calidad).

---

## 1. Estructura del Directorio

```text
colaboracion/
├── README.md                                    # Indice y guia operativa del flujo colaborativo
├── relevo.md                                    # Archivo activo de transicion y estado entre agentes
├── diffs/                                       # Diffs unificados generados para revision y auditoria
│   └── git_diff_issue_57.diff                   # Diff unificado del Issue #57
├── dictamenes/                                  # Dictamenes tecnicos estructurados emitidos por Claude
│   ├── dictamen_fase1_issue_57.md               # Dictamen de diseno y arquitectura (Fase 1)
│   ├── dictamen_fase3_issue_57.md               # Dictamen de auditoria de codigo inicial (Fase 3)
│   ├── dictamen_fase3_auditoria_corta_issue_57.md # Dictamen de auditoria corta de verificacion (Fase 3)
│   └── dictamen_fase3_cierre_issue_57.md        # Dictamen de cierre y aprobacion final de Fase 3
└── reglas/                                      # Normativa, estandares y configuracion operativa
    ├── CLAUDE.md                                # Archivo de reglas archivado (el canonico es CLAUDE.md en raiz)
    ├── PROTOCOLO_COLABORACION_CLAUDE_ANTIGRAVITY.md # Protocolo formal del ciclo de relevo en 4 fases
    └── REGLAS_GENERALES_DESARROLLO.md           # Reglas de Git, ramas, commits, PRs y estilo
```

---

## 2. Roles y Distribucion de Responsabilidades

| Agente | Rol Principal | Entorno de Ejecucion | Responsabilidades Clave |
| :--- | :--- | :--- | :--- |
| **Claude** | Lead Software Architect & QA Auditor | Claude Desktop (Windows) / Claude.ai | Diseno de contratos de datos, evaluacion de casos borde, auditoria de seguridad (OWASP, Spring Security) y emision de dictamenes estructurados. |
| **Antigravity** | Senior Software Engineer & DevOps | IDE Antigravity / PowerShell | Implementacion de codigo, ejecucion de compilaciones (`mvn`, `npm`), ejecucion de pruebas, gestion de Docker/AWS, generacion de diffs y preparacion de relevos. |
| **Usuario** | Controlador y Tomador de Decisiones | Consola / Aplicaciones | Punto de control humano que aprueba directivas, transfiere los relevos entre agentes y autoriza formalmente commits y despliegues. |

---

## 3. Ciclo de Vida del Relevo (4 Fases)

1. **Fase 1 - Diseno y Dominio (Claude):**
   - Antigravity plantea el problema y alternativas en [`colaboracion/relevo.md`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/colaboracion/relevo.md).
   - El usuario entrega el relevo a Claude.
   - Claude emite su dictamen en [`colaboracion/dictamenes/`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/colaboracion/dictamenes/).

2. **Fase 2 - Implementacion y Pruebas (Antigravity):**
   - El usuario autoriza a Antigravity la ejecucion de la propuesta aprobada.
   - Antigravity implementa la solucion, ejecuta las suites de pruebas automatizadas y garantiza compilacion limpia.

3. **Fase 3 - Auditoria de Codigo (Claude):**
   - Antigravity genera el diff unificado en [`colaboracion/diffs/`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/colaboracion/diffs/) y actualiza [`colaboracion/relevo.md`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/colaboracion/relevo.md).
   - Claude audita el diff en busca de vulnerabilidades, regresiones o inconsistencias tecnicas.
   - Si Claude solicita ajustes, Antigravity los subsana y se emite un nuevo relevo.

4. **Fase 4 - Aprobacion, Commits y Pull Request (Antigravity & Usuario):**
   - Con el dictamen `APROBADO` de Claude, Antigravity solicita al usuario la autorizacion formal para commitear.
   - Con autorizacion explicita del usuario, se realizan los commits en espanol (Conventional Commits), se hace push y se entrega la plantilla de Pull Request.

---

## 4. Politica de Higiene en el Repositorio de Codigo

Los archivos ubicados dentro de `colaboracion/` corresponden a la gestion operativa interna entre agentes.
- No forman parte del codigo fuente de los microservicios ni del frontend.
- No deben ser incluidos en los commits de funcionalidad de los issues tecnicos, manteniendo el historial de Git estrictamente enfocado en cambios de produccion e infraestructura.

---

## 5. Orden Obligatorio de Despliegue y Ventana de Corte (Issue #57)

Para evitar que consumidores antiguos descarten eventos con campos nuevos o que la aplicacion falle por discrepancia de esquema DDL, el despliegue debe seguir estrictamente este orden:

1. **Paso 1 - Notificaciones:** Desplegar `ms-rutaexpress-notificaciones` (posee el `ObjectMapper` tolerante a campos estructurados nuevos sin romper con eventos en transito).
2. **Paso 2 - Base de Datos Oracle (Fase A):** 
   - Ejecutar `infra/oracle/06_catalogo_geografico.sql` (crea tablas `REGIONES` y `COMUNAS` con 346 comunas oficiales).
   - Ejecutar `infra/oracle/07a_migracion_direcciones_envios.sql` (crea respaldo `ENVIOS_BKP_ISSUE57`, agrega columnas y claves foraneas, y efectua backfill).
   - Realizar la revision visual humana de la consulta de reconciliacion verificando que las columnas `coincide_origen` y `coincide_destino` marquen `OK`.
3. **Paso 3 - Base de Datos Oracle (Fase B / Inicio de Ventana de Corte):**
   - Ejecutar `infra/oracle/07b_migracion_direcciones_envios_cierre.sql` (aplica `NOT NULL` y elimina las columnas legacy `direccion_origen` y `direccion_destino`).
   - **Atencion - Ventana de Indisponibilidad:** Entre la ejecucion de este paso y el arranque del nuevo backend de envios, la version antigua desplegada fallara ante cualquier consulta de direcciones. Ambos pasos deben ejecutarse de manera estrictamente consecutiva en una ventana programada.
4. **Paso 4 - Microservicio Envios (Cierre de Ventana de Corte):** Desplegar `ms-rutaexpress-envios` (valida el esquema normalizado 3FN con `ddl-auto=validate`, cierra la ventana de corte y publica eventos estructurados).
5. **Paso 5 - BFF:** Desplegar `ms-rutaexpress-bff` (enruta los endpoints `/geografia/regiones` y `/geografia/regiones/{id}/comunas`).
6. **Paso 6 - Frontend:** Desplegar `rutaexpress-frontend` (consume el catalogo territorial y despliega el formulario con validacion comunal).

### Procedimiento ante Rollback y Reintento
- En caso de contingencia, ejecutar `infra/oracle/08_rollback_direcciones_issue57.sql`. El script restaura las columnas legacy y recompone los datos de forma segura sin destruir la tabla `ENVIOS`.
- La tabla de respaldo `ENVIOS_BKP_ISSUE57` se conserva deliberadamente tras el rollback para proteccion de datos.
- Para reintentar una nueva migracion una vez subsanada la causa, se debe eliminar explicitamente el respaldo verificado ejecutando:
  `DROP TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE57 PURGE;`
