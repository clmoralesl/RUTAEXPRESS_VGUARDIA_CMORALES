-- =============================================================================
-- Script: 08_rollback_direcciones_issue57.sql
-- Descripcion: Procedimiento de Rollback resiliente de la normalizacion de direcciones.
--              Capaz de revertir tanto un cierre completo (post 07b) como un estado
--              parcial interrumpido (post 07a).
-- Proyecto: RutaExpress (Issue #57)
-- Esquema: USER_ENVIOS
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- -----------------------------------------------------------------------------
-- PASO 1: Validar existencia e integridad de la tabla de respaldo
-- -----------------------------------------------------------------------------
DECLARE
    v_existe NUMBER := 0;
    v_filas  NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe 
    FROM USER_TABLES 
    WHERE table_name = 'ENVIOS_BKP_ISSUE57';

    IF v_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'No existe la tabla de respaldo ENVIOS_BKP_ISSUE57. Rollback cancelado para proteger los datos.');
    END IF;

    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ENVIOS.ENVIOS_BKP_ISSUE57' INTO v_filas;
    IF v_filas = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'La tabla de respaldo ENVIOS_BKP_ISSUE57 se encuentra vacia. Rollback cancelado.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Reincorporar columnas legacy condicionalmente (solo si fueron eliminadas)
-- -----------------------------------------------------------------------------
DECLARE
    v_cols NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols
    FROM USER_TAB_COLS
    WHERE table_name = 'ENVIOS' AND column_name = 'DIRECCION_ORIGEN';

    IF v_cols = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS ADD (direccion_origen VARCHAR2(255), direccion_destino VARCHAR2(255))';
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 3: Restaurar direcciones originales desde el respaldo por ID
-- -----------------------------------------------------------------------------
MERGE INTO USER_ENVIOS.ENVIOS e
USING USER_ENVIOS.ENVIOS_BKP_ISSUE57 b
ON (e.id = b.id)
WHEN MATCHED THEN
    UPDATE SET e.direccion_origen = b.direccion_origen,
               e.direccion_destino = b.direccion_destino;

-- -----------------------------------------------------------------------------
-- PASO 4: Para envios nuevos creados post-migracion, recomponer la direccion legacy
--         (si las columnas estructuradas existen)
-- -----------------------------------------------------------------------------
DECLARE
    v_cols NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols
    FROM USER_TAB_COLS
    WHERE table_name = 'ENVIOS' AND column_name = 'CALLE_ORIGEN';

    IF v_cols > 0 THEN
        EXECUTE IMMEDIATE '
            UPDATE USER_ENVIOS.ENVIOS e
            SET e.direccion_origen = (
                    SELECT TRIM(e.calle_origen || '' '' || e.numero_origen || 
                           NVL2(e.complemento_origen, '', '' || e.complemento_origen, '''') || 
                           NVL2(c.nombre, '', '' || c.nombre, '''') ||
                           NVL2(r.nombre, '', '' || r.nombre, ''''))
                    FROM USER_ENVIOS.COMUNAS c
                    LEFT JOIN USER_ENVIOS.REGIONES r ON r.id_region = c.id_region
                    WHERE c.id_comuna = e.id_comuna_origen
                ),
                e.direccion_destino = (
                    SELECT TRIM(e.calle_destino || '' '' || e.numero_destino || 
                           NVL2(e.complemento_destino, '', '' || e.complemento_destino, '''') || 
                           NVL2(c.nombre, '', '' || c.nombre, '''') ||
                           NVL2(r.nombre, '', '' || r.nombre, ''''))
                    FROM USER_ENVIOS.COMUNAS c
                    LEFT JOIN USER_ENVIOS.REGIONES r ON r.id_region = c.id_region
                    WHERE c.id_comuna = e.id_comuna_destino
                )
            WHERE e.direccion_origen IS NULL OR e.direccion_destino IS NULL';
    END IF;
END;
/

COMMIT;

-- -----------------------------------------------------------------------------
-- PASO 5: Validar que no queden valores nulos antes de aplicar NOT NULL
-- -----------------------------------------------------------------------------
DECLARE
    v_nulos NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_nulos 
    FROM USER_ENVIOS.ENVIOS 
    WHERE direccion_origen IS NULL OR direccion_destino IS NULL;

    IF v_nulos > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Existen filas con direccion_origen o direccion_destino nulas tras reconstruccion. Abortando rollback.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 6: Restaurar restricciones NOT NULL en columnas legacy condicionalmente
--         (evita ORA-01442 si el script 07a fallo antes de DROP COLUMN)
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- PASO 7: Eliminar restricciones de clave foranea e indices nuevos condicionalmente
-- -----------------------------------------------------------------------------
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS WHERE constraint_name = 'FK_ENVIOS_COMUNA_ORIGEN';
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS DROP CONSTRAINT fk_envios_comuna_origen';
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_CONSTRAINTS WHERE constraint_name = 'FK_ENVIOS_COMUNA_DESTINO';
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS DROP CONSTRAINT fk_envios_comuna_destino';
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_INDEXES WHERE index_name = 'IDX_ENVIOS_COMUNA_ORIGEN';
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP INDEX USER_ENVIOS.idx_envios_comuna_origen';
    END IF;

    SELECT COUNT(*) INTO v_count FROM USER_INDEXES WHERE index_name = 'IDX_ENVIOS_COMUNA_DESTINO';
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP INDEX USER_ENVIOS.idx_envios_comuna_destino';
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 8: Eliminar columnas normalizadas condicionalmente si existen
-- -----------------------------------------------------------------------------
DECLARE
    v_cols NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols
    FROM USER_TAB_COLS
    WHERE table_name = 'ENVIOS' AND column_name = 'CALLE_ORIGEN';

    IF v_cols > 0 THEN
        EXECUTE IMMEDIATE '
            ALTER TABLE USER_ENVIOS.ENVIOS DROP (
                calle_origen,
                numero_origen,
                complemento_origen,
                id_comuna_origen,
                calle_destino,
                numero_destino,
                complemento_destino,
                id_comuna_destino
            )';
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 9: Verificacion final del estado de la tabla
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS total_envios_restaurados FROM USER_ENVIOS.ENVIOS;

PROMPT =============================================================================
PROMPT ROLLBACK COMPLETADO SATISFACTORIAMENTE.
PROMPT LA TABLA USER_ENVIOS.ENVIOS HA SIDO RESTAURADA A SU ESTADO PRE-MIGRACION.
PROMPT =============================================================================
