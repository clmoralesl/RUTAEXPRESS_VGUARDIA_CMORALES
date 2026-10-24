# RELEVO TECNICO: ANTIGRAVITY -> CLAUDE (DESKTOP WINDOWS)
**Issue:** #57 - [Feature] Generación Automática de Código de Seguimiento y Normalización de Direcciones de Envio  
**URL Issue:** https://github.com/clmoralesl/RUTAEXPRESS_VGUARDIA_CMORALES/issues/57  
**Fecha:** 2026-10-24  
**Fase:** Fase 4 (Completada) - Commits, Pushes y Pull Requests Creados en GitHub  
**Archivo Git Diff Unificado:** [`git_diff_issue_57.diff`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/colaboracion/diffs/git_diff_issue_57.diff) (5.097 líneas)  

---

## 1. Resumen de Ajustes Realizados (Respuesta a `colaboracion/dictamenes/dictamen_fase3_auditoria_corta_issue_57.md`)

Se atendieron en su totalidad los ajustes obligatorios (A-1, A-2) y las mejoras de calidad sugeridas (N-1, N-3, N-4, N-5, N-6):

### A-1. Prueba Real de Resiliencia en Deserializacion (`ms-rutaexpress-notificaciones`)
- **`RabbitMQConfig.java`:**
  Se extrajo el método público estático `construirObjectMapper()`, asegurando que tanto el bean de producción (`jsonMessageConverter`) como los tests utilicen la misma instancia con `JavaTimeModule` y `FAIL_ON_UNKNOWN_PROPERTIES = false`.
- **`DeserializacionResilienteTest.java`:**
  - Se eliminaron los campos no utilizados y la instanciación local arbitraria de `ObjectMapper`.
  - Los tests ahora invocan `RabbitMQConfig.construirObjectMapper()`.
  - Los payloads JSON de prueba incorporan todos los campos estructurados normalizados (`calleOrigen`, `numeroOrigen`, `complementoOrigen`, `comunaOrigen`, `regionOrigen`, `calleDestino`, `numeroDestino`, etc.) junto a atributos desconocidos arbitrarios.
  - Se agregó una prueba de contraste `testObjectMapperEstandarFallaAnteCamposDesconocidos` que demuestra que sin la configuración de `RabbitMQConfig`, Jackson lanza `UnrecognizedPropertyException`.
- **Validacion:** Suite completa con 16 pruebas ejecutadas exitosamente (0 fallos, 0 errores).

### A-2. Pausa Obligatoria de Revision Humana y Alerta Visual (`infra/oracle/`)
Se dividió el script de migración en dos partes independientes:
1. **`07a_migracion_direcciones_envios.sql` (Pasos 1 a 7):**
   - Ejecuta guardas de tabla de respaldo y verificación de códigos legados.
   - Crea `ENVIOS_BKP_ISSUE57`.
   - Agrega las 8 columnas estructuradas, claves foráneas a `COMUNAS` e índices.
   - Ejecuta el backfill catalogado para los 12 envíos existentes y realiza `COMMIT`.
   - Valida ausencia de nulos tras el backfill (aborta si hay inconsistencias).
   - Ejecuta la **consulta de reconciliación visual** incorporando columnas de evaluación automática:
     ```sql
     CASE WHEN INSTR(UPPER(e.direccion_origen), UPPER(e.calle_origen)) > 0
           AND INSTR(UPPER(e.direccion_origen), UPPER(co.nombre)) > 0
          THEN 'OK' ELSE 'REVISAR' END AS coincide_origen,
     CASE WHEN INSTR(UPPER(e.direccion_destino), UPPER(e.calle_destino)) > 0
           AND INSTR(UPPER(e.direccion_destino), UPPER(cd.nombre)) > 0
          THEN 'OK' ELSE 'REVISAR' END AS coincide_destino
     ```
   - El script termina aquí con un prompt explícito, deteniendo la ejecución antes de aplicar cualquier DDL destructivo.
2. **`07b_migracion_direcciones_envios_cierre.sql` (Pasos 8 a 10):**
   - Requiere autorización humana tras la inspección visual de `07a`.
   - Valida que existan las 6 columnas estructuradas obligatorias y que no haya nulos.
   - Aplica `NOT NULL` a `calle_origen`, `numero_origen`, `id_comuna_origen`, `calle_destino`, `numero_destino`, `id_comuna_destino`.
   - Ejecuta `ALTER TABLE USER_ENVIOS.ENVIOS DROP (direccion_origen, direccion_destino);`.
   - Actualiza los comentarios de diccionario de datos y ejecuta `COMMIT`.

### N-1 y B-1. Rollback Condicional y Resiliente (`infra/oracle/08_rollback_direcciones_issue57.sql`)
- Se transformaron todos los pasos DDL en bloques anónimos PL/SQL condicionales:
  - Reincorpora `direccion_origen` y `direccion_destino` consultando `USER_TAB_COLS`, evitando errores `ORA-01430` si `07a` falló antes del `DROP COLUMN`.
  - Recompone direcciones solo si las columnas estructuradas aún existen.
  - **Paso 6 (Fix B-1):** Se acondicionó la restauración de `NOT NULL` verificando si `nullable = 'Y'`, evitando el error `ORA-01442` cuando las columnas legadas ya eran `NOT NULL` (escenario de rollback ante fallo intermedio de `07a`).
  - Elimina restricciones foráneas e índices únicamente si existen en `USER_CONSTRAINTS` y `USER_INDEXES`.
  - Elimina las columnas estructuradas solo si están presentes en la tabla.
- Con esto, `08` puede ejecutarse exitosamente tanto tras un cierre completo de `07b` como ante una falla parcial a mitad de `07a`.

### Salvaguarda Adicional en Cierre (`infra/oracle/07b_migracion_direcciones_envios_cierre.sql`)
- En el Paso 1, antes de cualquier `DROP COLUMN`, se añadió la verificación estricta de existencia y contenido no vacío de `ENVIOS_BKP_ISSUE57` (`RAISE_APPLICATION_ERROR(-20006)` y `-20007`), blindando el paso irreversible.

### N-3. Neutralizacion Uniforme de Comas (`ms-rutaexpress-envios`)
- En `NormalizadorDireccion.java`, se generalizó la sustitución `normalizado.replace(',', ' ')` para todos los campos de texto recibidos, desacoplándolo del nombre del parámetro y protegiendo también el campo `numero`.

### N-4. Unificacion de Logica de Composicion de Direccion (`ms-rutaexpress-envios`)
- Se declaró público y estático el método `NormalizadorDireccion.componer(calle, numero, complemento, nombreComuna, nombreRegion)`.
- En `EventoEnvioKafka.java` y en `EnvioService.java`, todas las composiciones de dirección delegan directamente a la llamada estática `NormalizadorDireccion.componer(...)`, eliminando cualquier duplicación de lógica.

### N-5. Jerarquia de Archivos de Configuracion de Claude
- Se documentó en `colaboracion/README.md` que el archivo canónico que lee la aplicación de escritorio y herramientas de Claude es `CLAUDE.md` ubicado en la raíz del proyecto, el cual importa las reglas situadas en `colaboracion/reglas/`.

### N-6 y B-2. Orden Obligatorio de Despliegue y Ventana de Indisponibilidad
El orden obligatorio y la ventana de corte quedan documentados formalmente en la Sección 3 de este documento y en `colaboracion/README.md`.

---

## 2. Resultados Consolidados de Pruebas Automatizadas

| Repositorio | Suite de Pruebas | Ejecutadas | Fallos | Errores | Estado |
| :--- | :--- | :---: | :---: | :---: | :--- |
| `ms-rutaexpress-envios` | `mvn test` | **41** | 0 | 0 | **EXITOSO** |
| `ms-rutaexpress-notificaciones` | `mvn test` | **16** | 0 | 0 | **EXITOSO** |
| `ms-rutaexpress-bff` | `mvn test` | **29** | 0 | 0 | **EXITOSO** |
| `rutaexpress-frontend` | `ng test --watch=false` | **115** | 0 | 0 | **EXITOSO** |
| `rutaexpress-frontend` | `ng build` | Bundle prod | 0 | 0 | **EXITOSO** |

---

## 3. Orden Obligatorio de Despliegue en Produccion y Ventana de Corte

Para prevenir eventos rechazados o fallos por divergencia de esquema:
1. **Paso 1 - Notificaciones:** Desplegar `ms-rutaexpress-notificaciones` (ObjectMapper tolerante a campos nuevos).
2. **Paso 2 - Base de Datos Oracle ATP (Fase A):**
   - Ejecutar `infra/oracle/06_catalogo_geografico.sql`.
   - Ejecutar `infra/oracle/07a_migracion_direcciones_envios.sql`.
   - Inspeccionar la consulta visual: validar que las filas muestren `OK` en `coincide_origen` y `coincide_destino`.
3. **Paso 3 - Base de Datos Oracle ATP (Fase B / Inicio de Ventana de Corte):**
   - Ejecutar `infra/oracle/07b_migracion_direcciones_envios_cierre.sql` (elimina columnas legadas `direccion_origen` y `direccion_destino`).
   - *Ventana de Indisponibilidad:* La versión antigua de `ms-rutaexpress-envios` fallará ante consultas de direcciones. No crear envíos durante este lapso.
4. **Paso 4 - Microservicio Envios (Cierre de Ventana de Corte):**
   - Desplegar inmediatamente `ms-rutaexpress-envios` (inicia con `ddl-auto=validate` contra el esquema migrado y normalizado).
5. **Paso 5 - BFF:** Desplegar `ms-rutaexpress-bff`.
6. **Paso 6 - Frontend:** Desplegar `rutaexpress-frontend`.

### Consideraciones Operativas C-1:
- **Ensayo previo:** Se recomienda ensayar `06`, `07a`, `07b` y `08` antes de la migración definitiva.
- **Reejecución tras rollback:** Si se aplica `08`, la tabla `ENVIOS_BKP_ISSUE57` se conserva deliberadamente. Para reintentar la migración, se debe purgar el respaldo una vez validada la restauración:
  `DROP TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE57 PURGE;`

---

## 4. Archivos Afectados Listos para Revision de Claude

Para la emisión del dictamen final `APROBADO`, los archivos modificados en esta ronda son:
1. [`RabbitMQConfig.java`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/ms-rutaexpress-notificaciones/src/main/java/cl/rutaexpress/notificaciones/config/RabbitMQConfig.java)
2. [`DeserializacionResilienteTest.java`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/ms-rutaexpress-notificaciones/src/test/java/cl/rutaexpress/notificaciones/config/DeserializacionResilienteTest.java)
3. [`07a_migracion_direcciones_envios.sql`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/07a_migracion_direcciones_envios.sql)
4. [`07b_migracion_direcciones_envios_cierre.sql`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/07b_migracion_direcciones_envios_cierre.sql)
5. [`08_rollback_direcciones_issue57.sql`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/infra/oracle/08_rollback_direcciones_issue57.sql)
6. [`NormalizadorDireccion.java`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/ms-rutaexpress-envios/src/main/java/cl/rutaexpress/envios/service/NormalizadorDireccion.java)
7. [`EventoEnvioKafka.java`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/ms-rutaexpress-envios/src/main/java/cl/rutaexpress/envios/dto/EventoEnvioKafka.java)
8. [`git_diff_issue_57.diff`](file:///c:/Users/claud/Desktop/RUTAEXPRESS_VGUARDIA_CMORALES/colaboracion/diffs/git_diff_issue_57.diff)

---

## 5. Pull Requests Creados en GitHub (Fase 4 Completada)

Todos los Pull Requests fueron creados en GitHub utilizando las credenciales institucionales de `clmoralesl`:
1. **Infraestructura Oracle (Raiz):** [PR #58](https://github.com/clmoralesl/RUTAEXPRESS_VGUARDIA_CMORALES/pull/58)
2. **Microservicio Envios:** [PR #10](https://github.com/clmoralesl/ms-rutaexpress-envios/pull/10)
3. **Microservicio Notificaciones:** [PR #2](https://github.com/clmoralesl/ms-rutaexpress-notificaciones/pull/2)
4. **Microservicio BFF:** [PR #14](https://github.com/clmoralesl/ms-rutaexpress-bff/pull/14)
5. **Frontend Angular:** [PR #22](https://github.com/clmoralesl/rutaexpress-frontend/pull/22)
