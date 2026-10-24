-- =============================================================================
-- Script: 07b_migracion_direcciones_envios_cierre.sql
-- Descripcion: Fase B de migracion: Restricciones NOT NULL, eliminacion segura
--              de columnas legadas (DROP COLUMN) y actualizacion de comentarios.
-- Proyecto: RutaExpress (Issue #57)
-- Esquema: USER_ENVIOS
-- Dependencia: Requiere ejecucion y revision visual previa de 07a_migracion_direcciones_envios.sql
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- -----------------------------------------------------------------------------
-- PASO 1: Verificacion de pre-requisitos de Fase A y existencia de respaldo
-- -----------------------------------------------------------------------------
DECLARE
    v_nulos NUMBER := 0;
    v_cols  NUMBER := 0;
    v_bkp_existe NUMBER := 0;
    v_bkp_filas  NUMBER := 0;
BEGIN
    -- Validar que la tabla de respaldo exista en USER_ENVIOS y no este vacia
    SELECT COUNT(*) INTO v_bkp_existe
    FROM ALL_TABLES
    WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS_BKP_ISSUE57';

    IF v_bkp_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'No existe la tabla de respaldo USER_ENVIOS.ENVIOS_BKP_ISSUE57. Ejecute primero 07a_migracion_direcciones_envios.sql.');
    END IF;

    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ENVIOS.ENVIOS_BKP_ISSUE57' INTO v_bkp_filas;
    IF v_bkp_filas = 0 THEN
        RAISE_APPLICATION_ERROR(-20007, 'La tabla de respaldo USER_ENVIOS.ENVIOS_BKP_ISSUE57 esta vacia. Abortando cierre por proteccion de datos.');
    END IF;

    -- Validar existencia de las columnas estructuradas en USER_ENVIOS.ENVIOS
    SELECT COUNT(*) INTO v_cols
    FROM ALL_TAB_COLS
    WHERE owner = 'USER_ENVIOS'
      AND table_name = 'ENVIOS' 
      AND column_name IN ('CALLE_ORIGEN', 'NUMERO_ORIGEN', 'ID_COMUNA_ORIGEN',
                          'CALLE_DESTINO', 'NUMERO_DESTINO', 'ID_COMUNA_DESTINO');

    IF v_cols < 6 THEN
        RAISE_APPLICATION_ERROR(-20004, 'No se han creado todas las columnas estructuradas requeridas en USER_ENVIOS.ENVIOS. Ejecute primero 07a_migracion_direcciones_envios.sql.');
    END IF;

    -- Validar que no existan valores nulos
    SELECT COUNT(*) INTO v_nulos
    FROM USER_ENVIOS.ENVIOS
    WHERE calle_origen IS NULL 
       OR numero_origen IS NULL 
       OR id_comuna_origen IS NULL
       OR calle_destino IS NULL 
       OR numero_destino IS NULL 
       OR id_comuna_destino IS NULL;

    IF v_nulos > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Existen ' || v_nulos || ' filas con columnas estructuradas nulas. Abortando cierre de migracion.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Aplicacion de restricciones NOT NULL
-- -----------------------------------------------------------------------------
ALTER TABLE USER_ENVIOS.ENVIOS MODIFY (
    calle_origen      NOT NULL,
    numero_origen     NOT NULL,
    id_comuna_origen  NOT NULL,
    calle_destino     NOT NULL,
    numero_destino    NOT NULL,
    id_comuna_destino NOT NULL
);

-- -----------------------------------------------------------------------------
-- PASO 3: Eliminacion de columnas desnormalizadas antiguas
-- -----------------------------------------------------------------------------
ALTER TABLE USER_ENVIOS.ENVIOS DROP (
    direccion_origen,
    direccion_destino
);

-- -----------------------------------------------------------------------------
-- PASO 4: Actualizacion de comentarios de documentacion del diccionario de datos
-- -----------------------------------------------------------------------------
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.codigo_seguimiento IS 'Codigo unico institucional de rastreo con formato RTX-YYYY-XXXXXX';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.calle_origen IS 'Nombre de calle, avenida o pasaje de origen';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.numero_origen IS 'Numero municipal o S/N de origen';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.complemento_origen IS 'Depto, oficina, block o referencia opcional de origen';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.id_comuna_origen IS 'Codigo CUT de la comuna de origen (FK a COMUNAS)';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.calle_destino IS 'Nombre de calle, avenida o pasaje de destino';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.numero_destino IS 'Numero municipal o S/N de destino';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.complemento_destino IS 'Depto, oficina, block o referencia opcional de destino';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.id_comuna_destino IS 'Codigo CUT de la comuna de destino (FK a COMUNAS)';

COMMIT;

PROMPT =============================================================================
PROMPT FASE B (CIERRE) COMPLETADA EXITOSAMENTE.
PROMPT LAS COLUMNAS DESNORMALIZADAS FUERON ELIMINADAS.
PROMPT EL ESQUEMA USER_ENVIOS.ENVIOS HA SIDO TOTALMENTE NORMALIZADO.
PROMPT =============================================================================
