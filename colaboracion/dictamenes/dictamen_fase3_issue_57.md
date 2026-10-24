# DICTAMEN TECNICO FASE 3: CLAUDE -> ANTIGRAVITY
**Issue:** #57 - Generacion Automatica de Codigo de Seguimiento y Normalizacion de Direcciones de Envio
**Respuesta a:** `.claude_relevo.md` (Fase 3 - Auditoria de Calidad y Seguridad)
**Fase:** Fase 3 con ajustes - vuelve a Fase 2 para correcciones, luego auditoria corta
**Dictamen previo de diseno:** `.claude_dictamen_issue_57.md`

---

### DICTAMEN DE RELEVO: REQUIERE_AJUSTES

El relevo no incluyo el `git diff` exigido por el protocolo, por lo que la auditoria se realizo leyendo el codigo directamente en los cinco repositorios. El diseno y la implementacion Java son solidos. Lo que impide la aprobacion son los scripts SQL (riesgo de perdida de datos) y un problema de orden de despliegue en `ms-rutaexpress-notificaciones`.

### Verificado por el auditor
- Se volvio a ejecutar `mvn test` en `ms-rutaexpress-envios`: 35 pruebas, 0 fallos, 0 errores (coincide con el relevo).
- `06_catalogo_geografico.sql` contiene 16 regiones y 346 comunas. Los codigos CUT usados en el backfill son correctos (por ejemplo 13123 Providencia, 5109 Vina del Mar, 8101 Concepcion).
- No se re-ejecutaron las pruebas de BFF, notificaciones ni frontend.
- No hay evidencia de que los scripts SQL se hayan ejecutado contra Oracle.

---

## 1. Evaluacion de Arquitectura y Seguridad

### 1.1 Aspectos correctos
- El rastreo publico expone solo `"Comuna, Region"`. `SeguimientoPublicoResponse` no contiene calle, numero ni RUT.
- Los publicadores de Kafka y RabbitMQ capturan sus excepciones; un fallo de mensajeria dentro de `afterCommit` no deja un envio creado con respuesta 500.
- `codigo_seguimiento` es `updatable = false` y el cliente no puede fijarlo.
- Los errores de comuna inexistente y de direccion invalida responden 400.
- El fallback de `EtiquetaService` y el aporte de `comunaDestino` y `regionDestino` al ticket de bodega son correctos.

### 1.2 Hallazgos bloqueantes

| ID | Componente | Hallazgo |
|---|---|---|
| B1 | `07_migracion_direcciones_envios.sql`, paso 1 | Ejecuta `DROP TABLE ENVIOS_BKP_ISSUE57` incondicionalmente. Si el script falla a medias y se reejecuta, el respaldo bueno se reemplaza por una copia ya migrada. Ademas, sin `WHENEVER SQLERROR EXIT`, SQL*Plus y SQLcl continuan tras un error. |
| B2 | `08_rollback_direcciones_issue57.sql` | Ejecuta `DROP TABLE ENVIOS` antes de comprobar que el respaldo existe, y el `EXCEPTION WHEN OTHERS` solo imprime el error. Si el respaldo falta, la tabla queda eliminada sin recuperacion. Aun si funciona, `CREATE TABLE AS SELECT` pierde la identidad de `id`, los indices (`idx_envios_codigo_seguimiento`), los comentarios y los valores por defecto. Tampoco contempla envios creados despues de la migracion, que no estan en el respaldo. |
| B3 | `07`, paso 3 | El backfill esta atado a 12 codigos fijos. Cualquier otro envio queda con comuna nula y el `NOT NULL` del paso 5 falla despues de haber agregado columnas y FK (el DDL de Oracle no se revierte). Ademas, nada verifica que las direcciones escritas a mano coincidan con el texto original: el paso 4 solo busca nulos. |
| B4 | `ms-rutaexpress-notificaciones`, `RabbitMQConfig` | Usa `new ObjectMapper()`, que por defecto falla ante propiedades desconocidas. La version actualmente desplegada de notificaciones enviara a la cola de rechazados los mensajes con campos nuevos. El cambio aditivo es correcto, pero solo es seguro con el orden de despliegue correcto y el mapper endurecido. |
| B5 | `CrearEnvioRequest` | El constructor "de compatibilidad" fabrica direcciones con valores fijos (`"Origen"`, numero `"1"`, comunas 13101 y 13123). Contradice el dictamen (sin modo de compatibilidad) y puede persistir datos falsos sin avisar. |
| B6 | Pruebas de `ms-rutaexpress-envios` | No existe prueba que verifique que el rastreo publico no contiene calle ni numero. Es la garantia central de privacidad del issue. |

### 1.3 Hallazgos no bloqueantes

| ID | Componente | Hallazgo |
|---|---|---|
| N1 | `NormalizadorDireccion` | Permite comas en calle y complemento (el dictamen pedia neutralizarlas). El numero acepta cualquier texto, por ejemplo `"abc"`. |
| N2 | Relevo, seccion 1 | Afirma "backoff exponencial" en los reintentos del codigo, pero el codigo solo vuelve a sortear, sin espera. Es correcto asi (la espera no aporta); debe corregirse la afirmacion. Una colision entre la consulta y el insert daria un 500 generico, con probabilidad del orden de 1e-9. |
| N3 | `EventoEnvioKafka` | La sobrecarga antigua de `deTransicion` compone el texto sin complemento ni region, con un formato distinto al resto. |
| N4 | `06_catalogo_geografico.sql` y `generar_catalogo.py` | El encabezado declara "Fuente oficial: CUT SUBDERE", pero el script descarga los datos de un repositorio comunitario de GitHub (`hsvchcl/chilean-territorial-divisions`). El origen real debe declararse. |
| N5 | Higiene Git | La matriz del relevo lista `DOCS/REGLAS_GENERALES_DESARROLLO.md` y `DOCS/PROTOCOLO_COLABORACION_CLAUDE_ANTIGRAVITY.md` como cambios del issue. Ya estaban sin seguimiento antes de iniciar el issue, no guardan relacion con el, y la seccion 2.2 de REGLAS sigue con la plantilla completa, no la "simplificada" que indica el relevo. |

---

## 2. Casos Borde Pendientes

1. Reejecucion del script `07` tras un fallo parcial (B1).
2. Envios creados desde la interfaz en la base real despues de los 12 conocidos (B3).
3. Rollback cuando el respaldo no existe, o cuando hay envios creados despues de la migracion (B2).
4. Mensaje nuevo dirigido a un consumidor antiguo (B4).
5. Esquema Oracle frente a la entidad JPA: las pruebas usan H2 con `import.sql`, por lo que `ddl-auto=validate` contra el DDL real nunca se ejercito.

---

## 3. Directivas de Implementacion para Antigravity

### A. `infra/oracle/07_migracion_direcciones_envios.sql`
1. Primera linea ejecutable: `WHENEVER SQLERROR EXIT FAILURE ROLLBACK`.
2. Reemplazar el `DROP` del respaldo por un bloqueo:

```sql
DECLARE v NUMBER;
BEGIN
  SELECT COUNT(*) INTO v FROM USER_TABLES WHERE table_name = 'ENVIOS_BKP_ISSUE57';
  IF v > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Ya existe ENVIOS_BKP_ISSUE57. Revisar antes de reejecutar.');
  END IF;
END;
/
```

3. Antes del paso 2 (antes de cualquier DDL): verificacion previa que aborte si existe algun `codigo_seguimiento` fuera de los 12 conocidos, listando los codigos encontrados.
4. Antes del paso 6 (`DROP`): consulta de reconciliacion que muestre `direccion_origen` y `direccion_destino` antiguos junto a las columnas nuevas, para revision del usuario. **Detenerse ahi y obtener su aprobacion.**

### B. `infra/oracle/08_rollback_direcciones_issue57.sql`
Reescribir sin eliminar la tabla:
1. Abortar si no existe el respaldo o si esta vacio.
2. Reagregar `direccion_origen` y `direccion_destino`, repoblarlas desde el respaldo por `id` y, para filas posteriores a la migracion, componerlas desde las columnas nuevas.
3. Comprobar que no queden nulos, restaurar `NOT NULL` y solo entonces eliminar FK, indices y columnas nuevas.
4. Eliminar el `EXCEPTION WHEN OTHERS` que traga errores.

### C. Ejecucion real de los scripts
1. Mostrar los scripts corregidos al usuario y obtener su aprobacion explicita.
2. Ejecutar `06` y `07` contra Oracle.
3. Arrancar `ms-rutaexpress-envios` con `ddl-auto=validate` contra la base migrada para confirmar que entidad y esquema coinciden.
4. Registrar los recuentos de `ENVIOS` antes y despues de la migracion.

### D. `ms-rutaexpress-notificaciones`
```java
ObjectMapper mapper = new ObjectMapper();
mapper.registerModule(new JavaTimeModule());
mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
```
- Agregar una prueba que deserialice un mensaje con campos desconocidos.
- **Orden de despliegue obligatorio:** notificaciones, luego envios, luego BFF, luego frontend. Documentarlo en el relevo y en el PR.

### E. `ms-rutaexpress-envios`
1. Eliminar el constructor de compatibilidad de `CrearEnvioRequest` y actualizar las pruebas afectadas con un helper de pruebas que arme direcciones estructuradas.
2. Pruebas nuevas:
   - El rastreo publico contiene comuna y region y **no** contiene calle ni numero (verificar sobre el JSON serializado).
   - `idComuna` inexistente responde 400.
   - Reintento ante codigo duplicado simulado.
   - Los eventos no se publican si la transaccion se revierte.
3. En `NormalizadorDireccion`: reemplazar comas por espacio en calle y complemento antes de validar. Exigir que el numero contenga al menos un digito o sea `S/N`.
4. Eliminar la sobrecarga antigua de `EventoEnvioKafka.deTransicion`, o hacer que use el mismo compositor que el resto.

### F. Documentacion y Git
1. Corregir en el relevo la afirmacion del backoff y la lista de archivos de `DOCS/`.
2. Declarar el origen real de los datos en el encabezado de `06` y en `generar_catalogo.py`. Decidir con el usuario si `generar_catalogo.py` se versiona.
3. El PR de cada repositorio incluye unicamente sus archivos del issue. No deben incluirse `CLAUDE.md`, `.claude_relevo.md`, `.claude_dictamen_issue_57.md`, este archivo, ni los archivos de `DOCS/` sin relacion con el issue.
4. Confirmar que `infra/oracle/wallet/` y `Wallet_*.zip` siguen ignorados (lo estaban en el momento de la auditoria).
5. Ningun commit ni push sin aprobacion explicita del usuario, mostrando antes el resumen y el `git diff`.

---

## 4. Respuestas a las Preguntas de Auditoria del Relevo

1. **Seguridad y privacidad:** validada en el codigo. Falta la prueba que la blinda (B6).
2. **Robustez y resiliencia:** el generador y el normalizador son adecuados, con los ajustes menores de N1 y N2. La robustez del cambio de base de datos no esta demostrada hasta resolver B1, B2, B3 y la directiva C.
3. **Compatibilidad event-driven:** aprobada condicionada a B4 (mapper endurecido y orden de despliegue).
4. **Cierre de Fase 3:** no aprobada. Tras aplicar las directivas A a F, Antigravity actualiza `.claude_relevo.md` con los resultados y el usuario lo devuelve a Claude para una auditoria corta, limitada a estos puntos. Aprobada esa revision, se solicita al usuario la autorizacion para commits y PR.

---

## 5. Criterios de Salida para la Auditoria Corta

- [ ] `07` y `08` corregidos, con evidencia de ejecucion contra Oracle y `ddl-auto=validate` exitoso.
- [ ] Recuentos de `ENVIOS` antes y despues de la migracion.
- [ ] Mapper de notificaciones endurecido, con su prueba.
- [ ] Constructor de compatibilidad eliminado y pruebas ajustadas.
- [ ] Pruebas nuevas de privacidad, comuna inexistente, reintento y publicacion tras rollback en verde.
- [ ] Resultados de `mvn test` y `ng test` actualizados en el relevo.
- [ ] Relevo corregido (backoff y lista de archivos) y orden de despliegue documentado.
