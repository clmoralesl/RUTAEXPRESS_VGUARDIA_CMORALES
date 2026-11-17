-- =============================================================================
-- Script: 15_limpieza_eventos_prueba_auditoria_issue85.sql
-- Descripcion: Limpieza con respaldo de eventos de prueba en historial de auditoria
--              conservando exclusivamente eventos consistentes con la tabla ENVIOS.
-- Proyecto: RutaExpress (Issue #85)
-- Esquema: USER_AUDITORIA / USER_ENVIOS
-- Conexion: Disenado para ejecutarse conectado como ADMIN.
-- Regla: Uso unico y excepcional: la tabla es inmutable por diseno; este script corrige datos de prueba (issue #85).
-- Nota: Si falla despues del PASO 2, el respaldo queda creado (el DDL confirma la transaccion).
--       Revisarlo y, si la tabla principal esta intacta, eliminarlo
--       (DROP TABLE USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 PURGE) antes de reintentar.
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET SERVEROUTPUT ON;

-- -----------------------------------------------------------------------------
-- PASO 1: Validacion estricta de precondiciones
-- -----------------------------------------------------------------------------
DECLARE
    v_existe_tabla NUMBER := 0;
    v_existe_bkp   NUMBER := 0;
    v_anomalias    NUMBER := 0;
BEGIN
    -- 1.1 Verificar existencia de la tabla principal
    SELECT COUNT(*) INTO v_existe_tabla
    FROM ALL_TABLES
    WHERE owner = 'USER_AUDITORIA' AND table_name = 'HISTORIAL_AUDITORIA';

    IF v_existe_tabla = 0 THEN
        RAISE_APPLICATION_ERROR(-20100, 'No existe la tabla USER_AUDITORIA.HISTORIAL_AUDITORIA. Abortando limpieza.');
    END IF;

    -- 1.2 Verificar que no exista tabla de respaldo previo
    SELECT COUNT(*) INTO v_existe_bkp
    FROM ALL_TABLES
    WHERE owner = 'USER_AUDITORIA' AND table_name = 'HISTORIAL_AUDITORIA_BKP_ISSUE85';

    IF v_existe_bkp > 0 THEN
        RAISE_APPLICATION_ERROR(-20101, 'Ya existe la tabla USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85. Revisar su contenido antes de reejecutar la limpieza.');
    END IF;

    -- 1.3 Verificar que no existan eventos con codigo real bajo otro envio_id (anomalia bloqueante D2)
    SELECT COUNT(*) INTO v_anomalias
    FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
    JOIN USER_ENVIOS.ENVIOS e ON e.codigo_seguimiento = h.codigo_seguimiento AND e.id != h.envio_id;

    IF v_anomalias > 0 THEN
        RAISE_APPLICATION_ERROR(-20102, 'Existen ' || v_anomalias || ' eventos cuyo codigo pertenece a otro envio_id en ENVIOS. Ejecutar 14_diagnostico_eventos_prueba_auditoria_issue85.sql y revisar antes de limpiar.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[INFO] Precondiciones validadas satisfactoriamente.');
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Creacion de la tabla de respaldo completo
-- -----------------------------------------------------------------------------
CREATE TABLE USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 AS
SELECT * FROM USER_AUDITORIA.HISTORIAL_AUDITORIA;

-- -----------------------------------------------------------------------------
-- PASO 3: Verificacion de integridad del respaldo
-- -----------------------------------------------------------------------------
DECLARE
    v_filas_tabla NUMBER := 0;
    v_filas_bkp   NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_filas_tabla FROM USER_AUDITORIA.HISTORIAL_AUDITORIA;
    SELECT COUNT(*) INTO v_filas_bkp   FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85;

    IF v_filas_tabla != v_filas_bkp THEN
        RAISE_APPLICATION_ERROR(-20103, 'Discrepancia en recuentos: tabla principal (' || v_filas_tabla
            || ') vs respaldo (' || v_filas_bkp || '). El servicio de auditoria podria seguir escribiendo; detenerlo y revisar.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[INFO] Respaldo creado exitosamente con ' || v_filas_bkp || ' registros.');
END;
/

-- Resumen inicial para auditoria
SELECT 'RECUENTO_TOTAL_INICIAL' AS categoria, COUNT(*) AS cantidad FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85
UNION ALL
SELECT 'EVENTOS_A_CONSERVAR' AS categoria, COUNT(*) AS cantidad
FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
WHERE EXISTS (
    SELECT 1 FROM USER_ENVIOS.ENVIOS e
    WHERE e.id = h.envio_id AND e.codigo_seguimiento = h.codigo_seguimiento
)
UNION ALL
SELECT 'EVENTOS_A_ELIMINAR' AS categoria, COUNT(*) AS cantidad
FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
WHERE NOT EXISTS (
    SELECT 1 FROM USER_ENVIOS.ENVIOS e
    WHERE e.id = h.envio_id AND e.codigo_seguimiento = h.codigo_seguimiento
);

-- -----------------------------------------------------------------------------
-- PASO 4: Limpieza transaccional controlada
-- -----------------------------------------------------------------------------
DECLARE
    v_total_bkp      NUMBER;
    v_esperadas      NUMBER;
    v_borradas       NUMBER;
    v_inconsistentes NUMBER;
    v_final          NUMBER;
BEGIN
    LOCK TABLE USER_AUDITORIA.HISTORIAL_AUDITORIA IN EXCLUSIVE MODE;

    SELECT COUNT(*) INTO v_total_bkp FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85;

    SELECT COUNT(*) INTO v_esperadas
    FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
    WHERE h.id IN (SELECT b.id FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 b)
      AND NOT EXISTS (
          SELECT 1 FROM USER_ENVIOS.ENVIOS e
          WHERE e.id = h.envio_id AND e.codigo_seguimiento = h.codigo_seguimiento
      );

    DELETE FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
    WHERE h.id IN (SELECT b.id FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 b)
      AND NOT EXISTS (
          SELECT 1 FROM USER_ENVIOS.ENVIOS e
          WHERE e.id = h.envio_id AND e.codigo_seguimiento = h.codigo_seguimiento
      );
    v_borradas := SQL%ROWCOUNT;

    IF v_borradas != v_esperadas THEN
        RAISE_APPLICATION_ERROR(-20104, 'Filas borradas (' || v_borradas || ') distintas de las esperadas (' || v_esperadas || ').');
    END IF;

    SELECT COUNT(*) INTO v_inconsistentes
    FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
    WHERE NOT EXISTS (
        SELECT 1 FROM USER_ENVIOS.ENVIOS e
        WHERE e.id = h.envio_id AND e.codigo_seguimiento = h.codigo_seguimiento
    );

    IF v_inconsistentes != 0 THEN
        RAISE_APPLICATION_ERROR(-20105, 'Quedan ' || v_inconsistentes || ' eventos sin par en ENVIOS tras la limpieza.');
    END IF;

    SELECT COUNT(*) INTO v_final FROM USER_AUDITORIA.HISTORIAL_AUDITORIA;
    IF v_final != v_total_bkp - v_borradas THEN
        RAISE_APPLICATION_ERROR(-20106, 'Recuento final ' || v_final || ' distinto de respaldo menos borradas (' || (v_total_bkp - v_borradas) || ').');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[INFO] Respaldo: ' || v_total_bkp || ' | Borradas: ' || v_borradas || ' | Conservadas: ' || v_final);
END;
/

-- -----------------------------------------------------------------------------
-- PASO 5: Recuentos finales para documentacion y evidencias
-- -----------------------------------------------------------------------------
SELECT 'RECUENTO INICIAL (RESPALDO)' AS origen, COUNT(*) AS total_filas FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85
UNION ALL
SELECT 'RECUENTO FINAL' AS origen, COUNT(*) AS total_filas FROM USER_AUDITORIA.HISTORIAL_AUDITORIA;

-- Desglose final de eventos conservados por envio
SELECT
    h.envio_id,
    h.codigo_seguimiento,
    COUNT(*) AS total_eventos
FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
GROUP BY h.envio_id, h.codigo_seguimiento
ORDER BY h.envio_id ASC;

COMMIT;
