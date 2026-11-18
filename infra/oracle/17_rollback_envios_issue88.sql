-- =============================================================================
-- Script: 17_rollback_envios_issue88.sql
-- Descripcion: Rollback condicional de la migracion 12 (pre-registro, instantaneas
--              de precio, medidas, verificacion y correo del remitente; issue #88).
-- Esquema: USER_ENVIOS
-- Conexion: ejecutar como ADMIN o USER_ENVIOS.
-- Orden de uso: primero desplegar la version anterior de ms-rutaexpress-envios y
--               despues ejecutar este script.
-- Regla: no borra la tabla ENVIOS ni ENVIOS_BKP_ISSUE88. Si hay datos nuevos,
--        los respalda en ENVIOS_PREREGISTRO_BKP_ISSUE88 antes de eliminar columnas.
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- PASO 1: validar existencia de la tabla principal
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

-- PASO 2: respaldo preventivo de los datos nuevos antes de eliminar columnas
DECLARE
    v_col        NUMBER := 0;
    v_filas      NUMBER := 0;
    v_tabla_bkp  NUMBER := 0;
    v_filas_bkp  NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_col
      FROM ALL_TAB_COLS
     WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS' AND column_name = 'SERVICIO_ID';

    IF v_col > 0 THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ENVIOS.ENVIOS WHERE servicio_id IS NOT NULL OR remitente_email IS NOT NULL'
            INTO v_filas;

        SELECT COUNT(*) INTO v_tabla_bkp
          FROM ALL_TABLES
         WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS_PREREGISTRO_BKP_ISSUE88';

        IF v_filas > 0 THEN
            IF v_tabla_bkp = 0 THEN
                EXECUTE IMMEDIATE 'CREATE TABLE USER_ENVIOS.ENVIOS_PREREGISTRO_BKP_ISSUE88 AS '
                    || 'SELECT id, sucursal_origen_id, servicio_id, largo_declarado_cm, ancho_declarado_cm, alto_declarado_cm, '
                    || 'peso_verificado_kg, largo_verificado_cm, ancho_verificado_cm, alto_verificado_cm, '
                    || 'zona_estimada, factor_zona_estimado, tarifa_base_estimada, precio_kg_estimado, '
                    || 'peso_facturable_estimado_kg, precio_estimado_clp, zona_final, factor_zona_final, '
                    || 'tarifa_base_final, precio_kg_final, peso_facturable_final_kg, precio_final_clp, '
                    || 'remitente_email, verificado_por_email, fecha_aceptacion '
                    || 'FROM USER_ENVIOS.ENVIOS WHERE servicio_id IS NOT NULL OR remitente_email IS NOT NULL';
                DBMS_OUTPUT.PUT_LINE('[INFO] Respaldo ENVIOS_PREREGISTRO_BKP_ISSUE88 creado con ' || v_filas || ' filas.');
            ELSE
                EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ENVIOS.ENVIOS_PREREGISTRO_BKP_ISSUE88' INTO v_filas_bkp;
                IF v_filas_bkp != v_filas THEN
                    RAISE_APPLICATION_ERROR(-20005, 'ENVIOS_PREREGISTRO_BKP_ISSUE88 ya existe con ' || v_filas_bkp
                        || ' filas y hay ' || v_filas || ' filas con datos nuevos. Rollback abortado por seguridad.');
                END IF;
            END IF;
        END IF;
    END IF;
END;
/

-- PASO 3: eliminar indice si existe
DECLARE
    v_idx NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_idx
      FROM ALL_INDEXES
     WHERE owner = 'USER_ENVIOS' AND index_name = 'IDX_ENVIOS_REMITENTE_EMAIL';
    IF v_idx > 0 THEN
        EXECUTE IMMEDIATE 'DROP INDEX USER_ENVIOS.idx_envios_remitente_email';
    END IF;
END;
/

-- PASO 4: eliminar restricciones CHECK si existen
DECLARE
    v_con NUMBER := 0;
BEGIN
    FOR r IN (SELECT constraint_name
                FROM ALL_CONSTRAINTS
               WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS'
                 AND constraint_name IN ('CHK_ENVIOS_PESO_VERIFICADO', 'CHK_ENVIOS_MEDIDAS_DECL', 'CHK_ENVIOS_MEDIDAS_VERIF'))
    LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS DROP CONSTRAINT ' || r.constraint_name;
        v_con := v_con + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('[INFO] Restricciones eliminadas: ' || v_con);
END;
/

-- PASO 5: eliminar las 24 columnas si existen
DECLARE
    v_cols NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols
      FROM ALL_TAB_COLS
     WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS'
       AND column_name IN ('SUCURSAL_ORIGEN_ID','SERVICIO_ID','LARGO_DECLARADO_CM','ANCHO_DECLARADO_CM','ALTO_DECLARADO_CM',
           'PESO_VERIFICADO_KG','LARGO_VERIFICADO_CM','ANCHO_VERIFICADO_CM','ALTO_VERIFICADO_CM','ZONA_ESTIMADA',
           'FACTOR_ZONA_ESTIMADO','TARIFA_BASE_ESTIMADA','PRECIO_KG_ESTIMADO','PESO_FACTURABLE_ESTIMADO_KG',
           'PRECIO_ESTIMADO_CLP','ZONA_FINAL','FACTOR_ZONA_FINAL','TARIFA_BASE_FINAL','PRECIO_KG_FINAL',
           'PESO_FACTURABLE_FINAL_KG','PRECIO_FINAL_CLP','REMITENTE_EMAIL','VERIFICADO_POR_EMAIL','FECHA_ACEPTACION');

    IF v_cols > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE USER_ENVIOS.ENVIOS DROP ('
            || 'sucursal_origen_id, servicio_id, largo_declarado_cm, ancho_declarado_cm, alto_declarado_cm, '
            || 'peso_verificado_kg, largo_verificado_cm, ancho_verificado_cm, alto_verificado_cm, '
            || 'zona_estimada, factor_zona_estimado, tarifa_base_estimada, precio_kg_estimado, '
            || 'peso_facturable_estimado_kg, precio_estimado_clp, zona_final, factor_zona_final, '
            || 'tarifa_base_final, precio_kg_final, peso_facturable_final_kg, precio_final_clp, '
            || 'remitente_email, verificado_por_email, fecha_aceptacion)';
    END IF;
END;
/

-- PASO 6: verificacion final
DECLARE
    v_restantes NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_restantes
      FROM ALL_TAB_COLS
     WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS'
       AND column_name IN ('SUCURSAL_ORIGEN_ID','SERVICIO_ID','LARGO_DECLARADO_CM','ANCHO_DECLARADO_CM','ALTO_DECLARADO_CM',
           'PESO_VERIFICADO_KG','LARGO_VERIFICADO_CM','ANCHO_VERIFICADO_CM','ALTO_VERIFICADO_CM','ZONA_ESTIMADA',
           'FACTOR_ZONA_ESTIMADO','TARIFA_BASE_ESTIMADA','PRECIO_KG_ESTIMADO','PESO_FACTURABLE_ESTIMADO_KG',
           'PRECIO_ESTIMADO_CLP','ZONA_FINAL','FACTOR_ZONA_FINAL','TARIFA_BASE_FINAL','PRECIO_KG_FINAL',
           'PESO_FACTURABLE_FINAL_KG','PRECIO_FINAL_CLP','REMITENTE_EMAIL','VERIFICADO_POR_EMAIL','FECHA_ACEPTACION');
    IF v_restantes > 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Persisten ' || v_restantes || ' columnas de la migracion 12 tras el rollback.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('[INFO] Rollback 17 correcto: 0 columnas de la migracion 12.');
END;
/

COMMIT;
