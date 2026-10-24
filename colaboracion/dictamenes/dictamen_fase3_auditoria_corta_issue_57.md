# DICTAMEN TECNICO FASE 3 (AUDITORIA CORTA): CLAUDE -> ANTIGRAVITY
**Issue:** #57 - Generacion Automatica de Codigo de Seguimiento y Normalizacion de Direcciones de Envio
**Respuesta a:** `colaboracion/relevo.md` y `colaboracion/diffs/git_diff_issue_57.diff` (4.879 lineas)
**Dictamen previo:** `colaboracion/dictamenes/dictamen_fase3_issue_57.md`
**Alcance de esta auditoria:** scripts SQL 06, 07 y 08; `ms-rutaexpress-envios`; `ms-rutaexpress-notificaciones`. BFF y frontend no cambiaron en esta ronda y no se re-auditaron.

---

### DICTAMEN DE RELEVO: REQUIERE_AJUSTES (menores)

Los 11 hallazgos del dictamen anterior (B1 a B6, N1 a N5) estan corregidos en el codigo. Quedan dos ajustes obligatorios y una condicion previa al merge. Son acotados: aplicados los dos ajustes, basta que el usuario me muestre solo los archivos afectados para emitir `APROBADO`, sin una nueva ronda completa de relevo.

### Verificado por el auditor
- `mvn test` re-ejecutado por Claude: `ms-rutaexpress-envios` 41 pruebas, 0 fallos, 0 errores; `ms-rutaexpress-notificaciones` 15 pruebas, 0 fallos, 0 errores. Coinciden con el relevo.
- No se re-ejecutaron las pruebas de BFF (29) ni de frontend (115).
- Backfill de `07` contrastado con las direcciones originales del commit `HEAD` de `03_data_envios.sql`: las 8 filas semilla (`RE-2026-001` a `RE-2026-008`) coinciden en calle, numero y codigo CUT de comuna.
- No verificable por el auditor: `RE-2026-010`, `RE-2026-011`, `RTX-297477` y `RTX-790284` no estan en el semilla; sus valores provienen de la base real.
- El relevo no aporta evidencia de que `06` y `07` se hayan ejecutado contra Oracle (el orden de despliegue los lista como pasos futuros).

---

## 1. Evaluacion de Arquitectura y Seguridad

### 1.1 Estado de los hallazgos previos

| ID | Estado | Observacion |
|---|---|---|
| B1 | Corregido | Guarda sobre `USER_TABLES` y `WHENEVER SQLERROR EXIT FAILURE ROLLBACK`. |
| B2 | Corregido | `08` ya no elimina `ENVIOS`. Valida respaldo, usa `MERGE`, recompone filas nuevas y aborta ante nulos. Ver N-1 sobre fallo parcial. |
| B3 | Parcial | Verificacion previa de codigos desconocidos correcta. La reconciliacion existe, pero no detiene el script (ver A-2). |
| B4 | Corregido en codigo, prueba invalida | El `ObjectMapper` de `RabbitMQConfig` tiene `FAIL_ON_UNKNOWN_PROPERTIES=false`. La prueba no valida esa configuracion (ver A-1). |
| B5 | Corregido | `CrearEnvioRequest` ya no tiene constructor de compatibilidad (0 constructores adicionales). Se agrego `TestEnvioFactory`. |
| B6 | Corregido | `testRastreoPublicoProtegePrivacidad` serializa el JSON y verifica ausencia de calle, numero y RUT. |
| N1 | Corregido | Comas neutralizadas en calle y complemento; el numero exige digito o `S/N`. Ver N-3. |
| N2 | Corregido | El relevo ya no afirma backoff. |
| N3 | Corregido | La sobrecarga de `EventoEnvioKafka.deTransicion` compone con complemento y region. Ver N-4. |
| N4 | Corregido | Origen real declarado en `06` y `generar_catalogo.py`. |
| N5 | Corregido | Archivos de coordinacion movidos a `colaboracion/`. |

### 1.2 Ajustes obligatorios

**A-1. `DeserializacionResilienteTest` no prueba la correccion de B4.**
La prueba declara `RabbitMQConfig` y `messageConverter`, pero nunca los usa: construye un `new ObjectMapper()` propio y le activa `FAIL_ON_UNKNOWN_PROPERTIES=false` dentro del test. Pasaria igual si se eliminara la linea corregida en `RabbitMQConfig`. La garantia que debia dar (la version desplegada no rechaza campos nuevos) queda sin cobertura real.

**A-2. `07` no se detiene antes de `DROP COLUMN`.**
El paso 7 (reconciliacion) es una consulta; el script continua de inmediato con el paso 8 (`NOT NULL`) y el paso 9 (`DROP direccion_origen, direccion_destino`). La directiva A.4 exigia detenerse para que el usuario revise. En una ejecucion normal del script la revision humana nunca ocurre. El respaldo y el rollback mitigan la perdida de datos, pero la salvaguarda pedida no existe.

### 1.3 Condicion previa al merge y despliegue

**C-1. Ejecucion real de los scripts contra Oracle (directiva C del dictamen anterior).**
Sin evidencia. Las pruebas usan H2 con `import.sql`, de modo que el DDL de `06` y `07` y `ddl-auto=validate` contra el esquema real nunca se han ejercitado. Requiere aprobacion explicita del usuario antes de ejecutar DDL en Oracle ATP.

### 1.4 Observaciones no bloqueantes

- **N-1. `08` solo sirve tras un `07` completo.** Si `07` falla entre los pasos 4 y 8 (por ejemplo, el FK falla porque `06` no se ejecuto), las columnas `direccion_*` aun existen y el paso 2 de `08` (`ADD direccion_origen`) falla con ORA-01430. El rollback no cubre el estado parcial.
- **N-2. Prueba de publicacion tras commit.** `testFalloPersistenciaNoPublicaKafka` verifica que si `save` lanza una excepcion no se publica; eso era cierto antes del cambio a `afterCommit`. No prueba el caso relevante (commit exitoso publica una vez, rollback no publica).
- **N-3. Comas en el numero y acoplamiento por nombre de campo.** `normalizarTexto` decide neutralizar comas segun si `nombreCampo` contiene "calle" o "complemento". El numero no se neutraliza (por ejemplo `"12,3"` pasa).
- **N-4. Logica de composicion duplicada.** `EventoEnvioKafka.componerDireccion` repite lo que hace `NormalizadorDireccion.componer`; pueden divergir.
- **N-5. Copia de `CLAUDE.md`.** Existe `colaboracion/reglas/CLAUDE.md` ademas del `CLAUDE.md` de la raiz. Claude Code solo lee el de la raiz; la copia puede quedar desactualizada.
- **N-6. Ventana de indisponibilidad.** Entre el paso 2 (migracion, elimina `direccion_*`) y el paso 3 (despliegue de `envios`) la version antigua de `envios` falla al consultar. Ejecutar ambos pasos de forma consecutiva y avisar la ventana.

---

## 2. Casos Borde Identificados

1. Ejecucion de `07` no supervisada: el `DROP COLUMN` se aplica sin revision humana (A-2).
2. Fallo de `07` a mitad de camino y uso de `08` en estado parcial (N-1).
3. Filas de la base real fuera del semilla (`RE-2026-010`, `RE-2026-011`, `RTX-297477`, `RTX-790284`): sus calles y comunas fueron escritas a mano y no pude contrastarlas.
4. Mensaje con campos nuevos hacia la version desplegada de notificaciones: el cambio de produccion es correcto, pero sin prueba valida (A-1).
5. Cambio de entidad contra esquema real: `ddl-auto=validate` no ejercitado (C-1).

---

## 3. Directivas de Implementacion para Antigravity

### A-1. Prueba que valide el mapper real
Extraer la construccion del mapper en `RabbitMQConfig` para que la usen el bean y la prueba:

```java
static ObjectMapper construirObjectMapper() {
    ObjectMapper mapper = new ObjectMapper();
    mapper.registerModule(new JavaTimeModule());
    mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
    return mapper;
}

@Bean
public MessageConverter jsonMessageConverter() {
    return new Jackson2JsonMessageConverter(construirObjectMapper());
}
```

En `DeserializacionResilienteTest`, reemplazar los `new ObjectMapper()` locales por `RabbitMQConfig.construirObjectMapper()` y eliminar los campos no usados (`rabbitMQConfig`, `messageConverter`). Incluir en el JSON de prueba los campos estructurados reales (`calleOrigen`, `comunaDestino`, etc.) ademas de uno desconocido. Verificacion de que la prueba es valida: al quitar temporalmente la linea `FAIL_ON_UNKNOWN_PROPERTIES` de `construirObjectMapper()`, la prueba debe fallar.

### A-2. Pausa real antes del `DROP COLUMN`
Opcion recomendada: dividir el script.
- `07a_migracion_direcciones_envios.sql`: pasos 1 a 7 (guardas, respaldo, columnas, backfill, verificacion de nulos, reconciliacion).
- `07b_migracion_direcciones_envios_cierre.sql`: pasos 8 a 10 (`NOT NULL`, `DROP COLUMN`, comentarios).
- Agregar a la reconciliacion una columna de alerta automatica, por ejemplo:

```sql
CASE WHEN INSTR(UPPER(e.direccion_origen), UPPER(e.calle_origen)) > 0
      AND INSTR(UPPER(e.direccion_origen), UPPER(co.nombre)) > 0
     THEN 'OK' ELSE 'REVISAR' END AS coincide_origen
```
(y su equivalente de destino), de modo que las filas con `REVISAR` salten a la vista. Las diferencias de tildes se resuelven revisando manualmente esas filas.

Alternativa: mantener un solo script e insertar antes del paso 8 un `ACCEPT confirmacion CHAR PROMPT 'Escriba SI para continuar: '` seguido de un bloque PL/SQL que lance `RAISE_APPLICATION_ERROR(-20006, ...)` si la respuesta no es `SI`.

El relevo debe documentar que el usuario revisa la reconciliacion y autoriza la ejecucion de `07b`.

### C-1. Ejecucion contra Oracle (previa al merge, con aprobacion del usuario)
1. Antes de `07a`, leer las filas reales y compararlas con el backfill:
   `SELECT codigo_seguimiento, direccion_origen, direccion_destino FROM USER_ENVIOS.ENVIOS ORDER BY id;`
   Prestar atencion a `RE-2026-010`, `RE-2026-011`, `RTX-297477` y `RTX-790284`.
2. Mostrar los scripts corregidos al usuario y esperar su aprobacion explicita antes de ejecutar DDL.
3. Ejecutar `06`, luego `07a`, revisar la reconciliacion con el usuario y ejecutar `07b`.
4. Arrancar `ms-rutaexpress-envios` con `ddl-auto=validate` contra la base migrada.
5. Registrar en el relevo: recuento de `ENVIOS` antes y despues, salida de la reconciliacion y resultado del arranque.
6. Si se opta por no ejecutar contra la base real antes del merge, declararlo en el relevo como riesgo asumido por el usuario.

### Recomendaciones no bloqueantes (aplicar si hay tiempo)
- N-1: hacer `08` condicional (agregar columnas `direccion_*` solo si no existen; eliminar FK, indices y columnas nuevas solo si existen), o documentar que `08` aplica unicamente despues de un `07b` completo y describir el procedimiento manual para estados parciales.
- N-2: prueba de integracion con `TransactionTemplate` que verifique que un commit publica una vez y un rollback no publica.
- N-3: neutralizar comas para todos los campos de texto de la direccion, sin depender del nombre del campo.
- N-4: que `EventoEnvioKafka` y el servicio usen un unico compositor.
- N-5: decidir con el usuario si se conserva `colaboracion/reglas/CLAUDE.md`; si se conserva, indicar en el README cual es el canonico.
- N-6: documentar en el relevo la ventana entre los pasos 2 y 3 del despliegue.

---

## 4. Respuestas a las Preguntas del Relevo

1. **Proteccion contra perdida de datos e integridad referencial en `07` y `08`:** si, con dos reservas. `07` tiene guardas, respaldo, verificacion de nulos y FK con indices; `08` ya no destruye la tabla y recompone los datos. Reservas: no hay pausa humana antes del `DROP COLUMN` (A-2) y los scripts no se han ejecutado contra Oracle (C-1).
2. **Hallazgos B1 a B6 y N1 a N5:** corregidos en codigo. B3 queda parcial por A-2 y B4 requiere una prueba valida (A-1).
3. **Aprobacion final de la Fase 3:** pendiente de A-1 y A-2. C-1 es condicion previa al merge y despliegue, no a los commits.

---

## 5. Criterios de Salida

- [ ] A-1: prueba de deserializacion que usa el mapper real y falla si se quita la configuracion.
- [ ] A-2: pausa real antes de `NOT NULL` y `DROP COLUMN`, con alerta automatica de coincidencias.
- [ ] `mvn test` en envios y notificaciones en verde tras los cambios.
- [ ] Relevo actualizado con el resultado.
- [ ] C-1 ejecutado con evidencia, o declarado como riesgo asumido por el usuario.
