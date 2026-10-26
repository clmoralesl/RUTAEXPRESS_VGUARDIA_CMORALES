-- =============================================================================
-- Script: 13_rollback_catalogo_issue83.sql
-- Descripcion: Rollback seguro y condicional para revertir tablas de sucursales,
--              zonas, geografia minima y columnas de limites del catalogo.
-- Proyecto: RutaExpress (Issue #83 - Sub-issue A: Catalogo)
-- Esquema: USER_CATALOGO
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_CATALOGO;

SET SERVEROUTPUT ON;

-- 1. Eliminar SERVICIO_COMUNA_EXCLUIDA
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM ALL_TABLES WHERE owner = 'USER_CATALOGO' AND table_name = 'SERVICIO_COMUNA_EXCLUIDA';
    IF v_existe > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE USER_CATALOGO.SERVICIO_COMUNA_EXCLUIDA CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('[OK] Tabla SERVICIO_COMUNA_EXCLUIDA eliminada.');
    END IF;
END;
/

-- 2. Eliminar columnas agregadas a SERVICIOS_CATALOGO
DECLARE
    v_cols NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cols 
    FROM ALL_TAB_COLS 
    WHERE owner = 'USER_CATALOGO' AND table_name = 'SERVICIOS_CATALOGO' 
      AND column_name IN ('PESO_MAXIMO_KG', 'LADO_MAXIMO_CM', 'VOLUMEN_MAXIMO_CM3', 'DIVISOR_VOLUMETRICO', 'PLAZO_MIN_DIAS', 'PLAZO_MAX_DIAS');
    
    IF v_cols > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE USER_CATALOGO.SERVICIOS_CATALOGO DROP (PESO_MAXIMO_KG, LADO_MAXIMO_CM, VOLUMEN_MAXIMO_CM3, DIVISOR_VOLUMETRICO, PLAZO_MIN_DIAS, PLAZO_MAX_DIAS)';
        DBMS_OUTPUT.PUT_LINE('[OK] Columnas de limites eliminadas de SERVICIOS_CATALOGO.');
    END IF;
END;
/

-- 3. Eliminar SUCURSALES
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM ALL_TABLES WHERE owner = 'USER_CATALOGO' AND table_name = 'SUCURSALES';
    IF v_existe > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE USER_CATALOGO.SUCURSALES CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('[OK] Tabla SUCURSALES eliminada.');
    END IF;
END;
/

-- 4. Eliminar TARIFA_ZONA
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM ALL_TABLES WHERE owner = 'USER_CATALOGO' AND table_name = 'TARIFA_ZONA';
    IF v_existe > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE USER_CATALOGO.TARIFA_ZONA CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('[OK] Tabla TARIFA_ZONA eliminada.');
    END IF;
END;
/

-- 5. Eliminar GEO_REGION_LIMITROFE
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM ALL_TABLES WHERE owner = 'USER_CATALOGO' AND table_name = 'GEO_REGION_LIMITROFE';
    IF v_existe > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE USER_CATALOGO.GEO_REGION_LIMITROFE CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('[OK] Tabla GEO_REGION_LIMITROFE eliminada.');
    END IF;
END;
/

-- 6. Eliminar GEO_REGION
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM ALL_TABLES WHERE owner = 'USER_CATALOGO' AND table_name = 'GEO_REGION';
    IF v_existe > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE USER_CATALOGO.GEO_REGION CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('[OK] Tabla GEO_REGION eliminada.');
    END IF;
END;
/

COMMIT;
