# DICTAMEN TECNICO FASE 3 (CIERRE): CLAUDE -> ANTIGRAVITY
**Issue:** #57 - Generacion Automatica de Codigo de Seguimiento y Normalizacion de Direcciones de Envio
**Respuesta a:** `colaboracion/relevo.md` (2026-10-24) y `colaboracion/diffs/git_diff_issue_57.diff` (5.065 lineas)
**Dictamen previo:** `colaboracion/dictamenes/dictamen_fase3_auditoria_corta_issue_57.md`
**Alcance:** `RabbitMQConfig`, `DeserializacionResilienteTest`, `NormalizadorDireccion`, `EventoEnvioKafka`, scripts `07a`, `07b` y `08`, y el procedimiento C-1 del relevo.

---

### DICTAMEN DE RELEVO: APROBADO (con una condicion bloqueante previa al commit de `infra/oracle/08`)

Los dos ajustes obligatorios (A-1 y A-2) estan correctamente resueltos. La arquitectura, el codigo de `envios` y `notificaciones` y la estrategia de migracion quedan aprobados para pasar a la Fase 4. Se detecto un defecto real en `08_rollback_direcciones_issue57.sql` que contradice lo declarado en el relevo (N-1); es un cambio de pocas lineas y debe aplicarse antes de commitear ese archivo. No requiere otra ronda completa de relevo.

### Verificado por el auditor
- Se leyeron directamente `07a`, `07b`, `08`, `RabbitMQConfig`, `DeserializacionResilienteTest`, `NormalizadorDireccion` y `EventoEnvioKafka`.
- `07_migracion_direcciones_envios.sql` (version anterior) ya no existe en `infra/oracle/`; fue reemplazado por `07a` y `07b`.
- Resultados de `mvn test` re-ejecutados por Claude: ver seccion 5.
- No se re-ejecutaron BFF (29) ni frontend (115): no cambiaron en esta ronda.
- Ningun script SQL se ha ejecutado contra Oracle (condicion C-1 pendiente, depende del usuario).

---

## 1. Evaluacion de Arquitectura y Seguridad

### 1.1 Estado de los ajustes

| ID | Estado | Observacion |
|---|---|---|
| A-1 | Resuelto | `RabbitMQConfig.construirObjectMapper()` es el unico origen del mapper (bean y pruebas). Las dos pruebas usan ese metodo, incluyen los campos estructurados reales mas campos desconocidos, y una tercera prueba demuestra que un `ObjectMapper` estandar lanza `UnrecognizedPropertyException`. |
| A-2 | Resuelto | `07a` termina tras la reconciliacion (con columnas `coincide_origen` y `coincide_destino`) y `07b` solo se ejecuta manualmente. `07b` valida columnas y nulos antes de `NOT NULL` y `DROP`. |
| N-3 | Resuelto | Las comas se neutralizan para todos los campos de texto, sin depender del nombre del campo. |
| N-4 | Resuelto | `EventoEnvioKafka.componerDireccion` delega en `NormalizadorDireccion.componer` (ahora estatico). |
| N-5 | Resuelto | `README.md` indica que el canonico es el `CLAUDE.md` de la raiz. |
| N-1 | Defecto (ver B-1) | La afirmacion "08 funciona ante una falla parcial de 07a" es incorrecta. |
| N-6 | Sin respaldo documental (ver B-2) | El relevo afirma que la ventana esta en "el orden de despliegue", pero esa seccion ya no existe en el relevo ni en el README. |
| N-2 | No abordado | El relevo no menciona la prueba de commit y rollback con `TransactionTemplate`. Sigue pendiente; no bloquea. |

### 1.2 Hallazgo bloqueante previo al commit

**B-1. `08` falla con ORA-01442 en el estado parcial que dice cubrir.**
Si `07a` se interrumpe despues de agregar columnas (caso probable: el FK falla porque `06` no se ejecuto), `direccion_origen` y `direccion_destino` siguen existiendo y siguen siendo `NOT NULL`. En ese estado, el paso 6 de `08` ejecuta `ALTER TABLE ... MODIFY (direccion_origen NOT NULL, direccion_destino NOT NULL)`. Oracle responde ORA-01442 ("column to be modified to NOT NULL is already NOT NULL") y, por `WHENEVER SQLERROR EXIT`, el script termina antes de los pasos 7 y 8: no elimina los FK, los indices ni las columnas nuevas. No hay perdida de datos, pero el rollback no completa su trabajo. El caso posterior a `07b` si funciona (las columnas legadas se recrean como nullable).

Fix obligatorio: volver condicional el paso 6.

```sql
DECLARE
    v_nullables NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_nullables
    FROM USER_TAB_COLS
    WHERE table_name = 'ENVIOS'
      AND column_name IN ('DIRECCION_ORIGEN', 'DIRECCION_DESTINO')
      AND nullable = 'Y';

    IF v_nullables > 0 THEN
        FOR c IN (SELECT column_name FROM USER_TAB_COLS
                  WHERE table_name = 'ENVIOS'
                    AND column_name IN ('DIRECCION_ORIGEN', 'DIRECCION_DESTINO')
                    AND nullable = 'Y') LOOP
            EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS MODIFY (' || c.column_name || ' NOT NULL)';
        END LOOP;
    END IF;
END;
/
```

### 1.3 Hallazgo documental

**B-2. Orden de despliegue y ventana de indisponibilidad no documentados.**
El relevo anterior traia el orden obligatorio (notificaciones, base de datos, envios, BFF, frontend). El relevo actual lo omite, y el procedimiento C-1 solo cubre base de datos y `envios`. Debe quedar escrito en un lugar que viaje con el codigo (descripcion del PR de `envios` y `colaboracion/README.md`), incluyendo la ventana entre `07b` y el despliegue de `envios`.

### 1.4 Observaciones sobre el procedimiento C-1

El procedimiento propuesto es correcto en su secuencia, con estas precisiones:

1. **Ejecutarlo "previo al merge" puede dejar la aplicacion en produccion rota.** En cuanto corre `07b`, la version actualmente desplegada de `envios` falla en toda consulta que lea `direccion_origen` o `direccion_destino`. Si el merge y el despliegue ocurren dias despues, esa ventana es larga. `07b` y el despliegue de `envios` deben ejecutarse de forma consecutiva en una ventana acordada. `06` y `07a` solo agregan objetos nuevos (columnas nullable) y no rompen la version antigua.
2. **Escrituras entre `07a` y `07b`.** Cualquier envio creado por la version antigua entre ambos scripts quedara con comuna nula; `07b` lo detecta y aborta (comportamiento correcto), pero obliga a resolverlo a mano. Evitar crear envios en ese intervalo.
3. **Reejecucion tras un fallo.** `07a` rechaza ejecutarse si existe `ENVIOS_BKP_ISSUE57`. Despues de usar `08`, el respaldo se conserva a proposito; para reintentar hay que eliminarlo manualmente (`DROP TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE57 PURGE;`) una vez verificado que la tabla quedo restaurada. Documentarlo.
4. **Ensayo del rollback.** Los 12 envios hacen barato un ensayo: ejecutar `06`, `07a`, `07b`, luego `08`, verificar el recuento y las direcciones, eliminar el respaldo y volver a migrar. Es la unica forma de comprobar `08` antes de necesitarlo.
5. **Cotejo de recuentos.** `07a` imprime los recuentos de `ENVIOS` y del respaldo; anotarlos en el relevo antes de ejecutar `07b`.

---

## 2. Casos Borde Identificados

1. Fallo de `07a` por falta de `06`: el rollback debe completarse (B-1).
2. Envios creados por la version antigua entre `07a` y `07b` (1.4, punto 2).
3. Reintento de `07a` tras un rollback sin eliminar el respaldo (1.4, punto 3).
4. Ventana de indisponibilidad entre `07b` y el despliegue de `envios` (B-2, 1.4 punto 1).
5. Filas fuera del conjunto de ejemplo (`RE-2026-010`, `RE-2026-011`, `RTX-297477`, `RTX-790284`): la columna `coincide_*` de la reconciliacion es la salvaguarda; las diferencias de tildes (`San Martin` frente a `San Martín`) apareceran como `REVISAR` y se resuelven a mano.

---

## 3. Directivas de Implementacion para Antigravity

### Condicion bloqueante previa al commit
1. Aplicar el fix B-1 al paso 6 de `infra/oracle/08_rollback_direcciones_issue57.sql` y corregir la afirmacion de N-1 en el relevo si se mantiene alguna reserva.
2. Aplicar B-2: incluir el orden de despliegue y la ventana en la descripcion del PR de `ms-rutaexpress-envios` y en `colaboracion/README.md`.

### Recomendaciones no bloqueantes
- Agregar a `07b`, antes del `DROP`, una verificacion de que `ENVIOS_BKP_ISSUE57` existe: es el unico paso irreversible y hoy no comprueba que su red de seguridad este presente.
- Resolver N-2: prueba con `TransactionTemplate` (commit publica una vez; rollback no publica).
- Llamar a `NormalizadorDireccion.componer` de forma estatica en `EnvioService` (hoy se invoca a traves de una instancia).
- Anadir al procedimiento C-1 los puntos 1 a 5 de la seccion 1.4.

### Higiene Git para la Fase 4
- `colaboracion/` y `CLAUDE.md` no forman parte de ningun commit del issue.
- Repositorio raiz: solo `infra/oracle/02_schema_envios.sql`, `03_data_envios.sql`, `06_catalogo_geografico.sql`, `07a_...`, `07b_...`, `08_...` y `generar_catalogo.py` (si el usuario decide versionarlo). Confirmar que `infra/oracle/wallet/` y `Wallet_*.zip` siguen ignorados.
- Una rama y un PR por repositorio: raiz, `ms-rutaexpress-envios`, `ms-rutaexpress-bff`, `ms-rutaexpress-notificaciones` y `rutaexpress-frontend`.
- Ningun commit ni push sin aprobacion explicita del usuario, mostrando antes el resumen y el `git diff` de cada repositorio.

---

## 4. Respuestas a las Preguntas del Relevo

1. **A-1 y A-2:** resueltos y validados.
2. **N-1:** la reescritura de `08` es una mejora, pero no cubre el estado parcial de `07a` hasta aplicar B-1.
3. **Aprobacion final de la Fase 3:** emitida, con la condicion bloqueante de la seccion 3 para el archivo `08`. C-1 (ejecucion contra Oracle) sigue siendo condicion previa al merge y despliegue, bajo autorizacion del usuario.

---

## 5. Pruebas Re-ejecutadas por el Auditor

| Repositorio | Comando | Ejecutadas | Fallos | Errores | Coincide con el relevo |
|---|---|---|---|---|---|
| `ms-rutaexpress-envios` | `mvn test` | 41 | 0 | 0 | Si |
| `ms-rutaexpress-notificaciones` | `mvn test` | 16 | 0 | 0 | Si |

BFF (29 pruebas) y frontend (115 pruebas y `ng build`) no se re-ejecutaron.
