-- =============================================================================
-- Script: 16_rollback_limpieza_auditoria_issue85.sql
-- Descripcion: Procedimiento de Rollback para restaurar eventos eliminados desde
--              la tabla de respaldo HISTORIAL_AUDITORIA_BKP_ISSUE85.
-- Proyecto: RutaExpress (Issue #85)
-- Esquema: USER_AUDITORIA
-- Conexion: Disenado para ejecutarse conectado como ADMIN.
-- Regla: Uso unico y excepcional: la tabla es inmutable por diseno; este script corrige datos de prueba (issue #85).
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET SERVEROUTPUT ON;

-- -----------------------------------------------------------------------------
-- PASO 1: Validar existencia de la tabla de respaldo
-- -----------------------------------------------------------------------------
DECLARE
    v_existe_bkp NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe_bkp
    FROM ALL_TABLES
    WHERE owner = 'USER_AUDITORIA' AND table_name = 'HISTORIAL_AUDITORIA_BKP_ISSUE85';

    IF v_existe_bkp = 0 THEN
        RAISE_APPLICATION_ERROR(-20111, 'No existe la tabla de respaldo USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85. Rollback abortado.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[INFO] Tabla de respaldo detectada.');
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Verificar tipo de generacion de identidad en columna ID
-- -----------------------------------------------------------------------------
DECLARE
    v_tipo_gen VARCHAR2(30);
BEGIN
    SELECT generation_type INTO v_tipo_gen
    FROM ALL_TAB_IDENTITY_COLS
    WHERE owner = 'USER_AUDITORIA'
      AND table_name = 'HISTORIAL_AUDITORIA'
      AND column_name = 'ID';

    IF UPPER(v_tipo_gen) = 'ALWAYS' THEN
        RAISE_APPLICATION_ERROR(-20112, 'La columna ID es GENERATED ALWAYS; no se puede restaurar conservando identificadores. Consultar antes de continuar.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[INFO] Tipo de identidad verificado: ' || v_tipo_gen);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Si no esta definida como columna identidad estricta en el diccionario, se permite reinsercion
        DBMS_OUTPUT.PUT_LINE('[INFO] La columna ID no figura como GENERATED ALWAYS en ALL_TAB_IDENTITY_COLS. Procediendo.');
END;
/

-- -----------------------------------------------------------------------------
-- PASO 3: Restaurar eventos faltantes desde el respaldo (idempotente / reentrante)
-- -----------------------------------------------------------------------------
DECLARE
    v_insertadas NUMBER := 0;
BEGIN
    INSERT INTO USER_AUDITORIA.HISTORIAL_AUDITORIA (
        id,
        evento_id,
        envio_id,
        codigo_seguimiento,
        estado_anterior,
        estado_nuevo,
        usuario_email,
        usuario_rol,
        fecha_evento,
        detalles_json,
        fecha_registro
    )
    SELECT
        b.id,
        b.evento_id,
        b.envio_id,
        b.codigo_seguimiento,
        b.estado_anterior,
        b.estado_nuevo,
        b.usuario_email,
        b.usuario_rol,
        b.fecha_evento,
        b.detalles_json,
        b.fecha_registro
    FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 b
    WHERE NOT EXISTS (
        SELECT 1 FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
        WHERE h.evento_id = b.evento_id
    );

    v_insertadas := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE('[INFO] Eventos restaurados desde respaldo: ' || v_insertadas);
END;
/

-- -----------------------------------------------------------------------------
-- PASO 4: Validar consistencia e integridad total post-restauracion
-- -----------------------------------------------------------------------------
DECLARE
    v_faltantes NUMBER := 0;
    v_total_bkp NUMBER := 0;
    v_total_tab NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_faltantes
    FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 b
    WHERE NOT EXISTS (
        SELECT 1 FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
        WHERE h.evento_id = b.evento_id
    );

    IF v_faltantes > 0 THEN
        RAISE_APPLICATION_ERROR(-20113, 'Persisten ' || v_faltantes || ' eventos del respaldo sin restaurar en HISTORIAL_AUDITORIA.');
    END IF;

    SELECT COUNT(*) INTO v_total_bkp FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85;
    SELECT COUNT(*) INTO v_total_tab FROM USER_AUDITORIA.HISTORIAL_AUDITORIA;

    DBMS_OUTPUT.PUT_LINE('[INFO] Verificacion completada: ' || v_total_bkp || ' en respaldo, ' || v_total_tab || ' en tabla principal.');
END;
/

-- -----------------------------------------------------------------------------
-- PASO 5: Confirmacion sin borrar la tabla de respaldo
-- -----------------------------------------------------------------------------
SELECT 'RECUENTO RESPALDO' AS tabla, COUNT(*) AS filas FROM USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85
UNION ALL
SELECT 'RECUENTO HISTORIAL_AUDITORIA' AS tabla, COUNT(*) AS filas FROM USER_AUDITORIA.HISTORIAL_AUDITORIA;

COMMIT;
