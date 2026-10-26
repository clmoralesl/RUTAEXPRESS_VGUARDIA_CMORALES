-- =============================================================================
-- Script: 09_agregar_propietario_envios.sql
-- Descripcion: Agrega columnas para registrar el usuario propietario (oid y email)
--              de cada envio, creando el indice correspondiente para optimizar
--              las consultas filtradas por propietario.
-- Proyecto: RutaExpress (Issue #69 - Backend BOLA/BFLA)
-- Esquema: USER_ENVIOS
-- Conexión: Diseñado para ejecutarse conectado como ADMIN o USER_ENVIOS.
-- Regla: Los envios legados existentes quedan con creado_por_oid = NULL (D3).
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- -----------------------------------------------------------------------------
-- PASO 1: Verificacion de respaldo previo (Evitar sobreescritura accidental)
-- -----------------------------------------------------------------------------
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe 
    FROM ALL_TABLES 
    WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS_BKP_ISSUE69';

    IF v_existe > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ya existe la tabla USER_ENVIOS.ENVIOS_BKP_ISSUE69. Revisar su contenido antes de reejecutar la migracion.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Creacion de la tabla de respaldo de seguridad
-- -----------------------------------------------------------------------------
CREATE TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE69 AS 
SELECT * FROM USER_ENVIOS.ENVIOS;

-- -----------------------------------------------------------------------------
-- PASO 3: Validacion de integridad del respaldo
-- -----------------------------------------------------------------------------
DECLARE
    v_filas_orig NUMBER := 0;
    v_filas_bkp  NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_filas_orig FROM USER_ENVIOS.ENVIOS;
    SELECT COUNT(*) INTO v_filas_bkp  FROM USER_ENVIOS.ENVIOS_BKP_ISSUE69;

    IF v_filas_orig != v_filas_bkp THEN
        RAISE_APPLICATION_ERROR(-20002, 'Discrepancia en recuento de filas entre ENVIOS (' || v_filas_orig || ') y respaldo (' || v_filas_bkp || '). Abortando.');
    END IF;
END;
/

SELECT COUNT(*) AS filas_originales FROM USER_ENVIOS.ENVIOS;
SELECT COUNT(*) AS filas_respaldo   FROM USER_ENVIOS.ENVIOS_BKP_ISSUE69;

-- -----------------------------------------------------------------------------
-- PASO 4: Agregar nuevas columnas de propiedad (Nullable para legados)
-- -----------------------------------------------------------------------------
ALTER TABLE USER_ENVIOS.ENVIOS ADD (
    creado_por_oid   VARCHAR2(36),
    creado_por_email VARCHAR2(320)
);

-- -----------------------------------------------------------------------------
-- PASO 5: Crear indice para busquedas por propietario
-- -----------------------------------------------------------------------------
CREATE INDEX USER_ENVIOS.idx_envios_creado_por_oid ON USER_ENVIOS.ENVIOS (creado_por_oid);

-- -----------------------------------------------------------------------------
-- PASO 6: Documentacion de columnas en el diccionario de datos
-- -----------------------------------------------------------------------------
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.creado_por_oid IS 'Identificador (oid) del usuario de Entra ID que creo el envio';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.creado_por_email IS 'Correo del creador, informativo y opcional';

-- -----------------------------------------------------------------------------
-- PASO 7: Verificacion final del esquema y recuento de filas
-- -----------------------------------------------------------------------------
DECLARE
    v_cols NUMBER := 0;
    v_filas_final NUMBER := 0;
    v_filas_bkp   NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols
    FROM ALL_TAB_COLS
    WHERE owner = 'USER_ENVIOS' 
      AND table_name = 'ENVIOS' 
      AND column_name IN ('CREADO_POR_OID', 'CREADO_POR_EMAIL');

    IF v_cols != 2 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Fallo la verificacion de columnas agregadas en USER_ENVIOS.ENVIOS.');
    END IF;

    SELECT COUNT(*) INTO v_filas_final FROM USER_ENVIOS.ENVIOS;
    SELECT COUNT(*) INTO v_filas_bkp   FROM USER_ENVIOS.ENVIOS_BKP_ISSUE69;

    IF v_filas_final != v_filas_bkp THEN
        RAISE_APPLICATION_ERROR(-20004, 'Discrepancia de filas tras migracion: ENVIOS=' || v_filas_final || ', RESPALDO=' || v_filas_bkp);
    END IF;

    DBMS_OUTPUT.PUT_LINE('[INFO] Recuento verificado: ' || v_filas_final || ' filas en ENVIOS y ' || v_filas_bkp || ' filas en ENVIOS_BKP_ISSUE69.');
END;
/

SELECT 'RECUENTO INICIAL (RESPALDO)' AS etapa, COUNT(*) AS total_filas FROM USER_ENVIOS.ENVIOS_BKP_ISSUE69
UNION ALL
SELECT 'RECUENTO FINAL (MIGRADO)' AS etapa, COUNT(*) AS total_filas FROM USER_ENVIOS.ENVIOS;

COMMIT;
