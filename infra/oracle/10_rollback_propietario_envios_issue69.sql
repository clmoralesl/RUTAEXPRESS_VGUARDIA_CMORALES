-- =============================================================================
-- Script: 10_rollback_propietario_envios_issue69.sql
-- Descripcion: Procedimiento de Rollback condicional y resiliente para revertir
--              las columnas de propietario y su indice agregado en Issue #69.
-- Proyecto: RutaExpress (Issue #69 - Backend BOLA/BFLA)
-- Esquema: USER_ENVIOS
-- Conexión: Diseñado para ejecutarse conectado como ADMIN o USER_ENVIOS.
-- Regla: No borra la tabla ENVIOS ni el respaldo; solo elimina de forma condicional
--        el indice y las columnas creadas si existen.
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- -----------------------------------------------------------------------------
-- PASO 1: Validar existencia de la tabla principal
-- -----------------------------------------------------------------------------
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe 
    FROM ALL_TABLES 
    WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS';

    IF v_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'No existe la tabla USER_ENVIOS.ENVIOS. Rollback abortado.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Eliminar indice condicionalmente si existe
-- -----------------------------------------------------------------------------
DECLARE
    v_idx NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_idx
    FROM ALL_INDEXES
    WHERE owner = 'USER_ENVIOS' AND index_name = 'IDX_ENVIOS_CREADO_POR_OID';

    IF v_idx > 0 THEN
        EXECUTE IMMEDIATE 'DROP INDEX USER_ENVIOS.idx_envios_creado_por_oid';
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2.1: Respaldo preventivo de datos de propietarios antes de eliminar columnas
-- -----------------------------------------------------------------------------
DECLARE
    v_filas_prop NUMBER := 0;
    v_tabla_bkp NUMBER := 0;
    v_filas_bkp NUMBER := 0;
    v_col_oid NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_col_oid
    FROM ALL_TAB_COLS
    WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS' AND column_name = 'CREADO_POR_OID';

    IF v_col_oid > 0 THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ENVIOS.ENVIOS WHERE creado_por_oid IS NOT NULL' INTO v_filas_prop;

        SELECT COUNT(*) INTO v_tabla_bkp
        FROM ALL_TABLES
        WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS_PROPIETARIO_BKP_ISSUE69';

        IF v_filas_prop > 0 THEN
            IF v_tabla_bkp = 0 THEN
                EXECUTE IMMEDIATE 'CREATE TABLE USER_ENVIOS.ENVIOS_PROPIETARIO_BKP_ISSUE69 AS SELECT id, creado_por_oid, creado_por_email FROM USER_ENVIOS.ENVIOS WHERE creado_por_oid IS NOT NULL';
                DBMS_OUTPUT.PUT_LINE('[INFO] Tabla de respaldo USER_ENVIOS.ENVIOS_PROPIETARIO_BKP_ISSUE69 creada con ' || v_filas_prop || ' registros.');
            ELSE
                EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ENVIOS.ENVIOS_PROPIETARIO_BKP_ISSUE69' INTO v_filas_bkp;
                IF v_filas_prop <> v_filas_bkp THEN
                    RAISE_APPLICATION_ERROR(-20005, 'La tabla de respaldo ENVIOS_PROPIETARIO_BKP_ISSUE69 ya existe con ' || v_filas_bkp || ' filas, diferente a las ' || v_filas_prop || ' filas con propietario actuales. Rollback abortado por seguridad.');
                END IF;
            END IF;
        END IF;
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 3: Eliminar columnas condicionalmente si existen
-- -----------------------------------------------------------------------------
DECLARE
    v_cols NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols
    FROM ALL_TAB_COLS
    WHERE owner = 'USER_ENVIOS' 
      AND table_name = 'ENVIOS' 
      AND column_name IN ('CREADO_POR_OID', 'CREADO_POR_EMAIL');

    IF v_cols > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS DROP (creado_por_oid, creado_por_email)';
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 4: Verificacion final de rollback
-- -----------------------------------------------------------------------------
DECLARE
    v_cols_restantes NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols_restantes
    FROM ALL_TAB_COLS
    WHERE owner = 'USER_ENVIOS' 
      AND table_name = 'ENVIOS' 
      AND column_name IN ('CREADO_POR_OID', 'CREADO_POR_EMAIL');

    IF v_cols_restantes > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Las columnas de propietario persisten tras el rollback.');
    END IF;
END;
/

COMMIT;
