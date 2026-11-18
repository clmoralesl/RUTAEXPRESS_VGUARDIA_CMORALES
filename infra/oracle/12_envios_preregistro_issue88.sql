-- Script: 12_envios_preregistro_issue88.sql
-- Descripcion: columnas opcionales de pre-registro, instantaneas de precio, medidas,
--              verificacion y correo del remitente en USER_ENVIOS.ENVIOS (issue #88).
-- Ejecutar como ADMIN o USER_ENVIOS, ANTES de desplegar ms-rutaexpress-envios.
-- Las filas existentes quedan con las columnas nuevas en NULL.
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

DECLARE v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM ALL_TABLES WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS_BKP_ISSUE88';
    IF v_existe > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ya existe USER_ENVIOS.ENVIOS_BKP_ISSUE88. Revisar antes de reejecutar.');
    END IF;
    SELECT COUNT(*) INTO v_existe FROM ALL_TAB_COLS WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS' AND column_name = 'SERVICIO_ID';
    IF v_existe > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'La columna SERVICIO_ID ya existe: la migracion 12 parece aplicada.');
    END IF;
END;
/

CREATE TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE88 AS SELECT * FROM USER_ENVIOS.ENVIOS;

DECLARE v_orig NUMBER; v_bkp NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_orig FROM USER_ENVIOS.ENVIOS;
    SELECT COUNT(*) INTO v_bkp FROM USER_ENVIOS.ENVIOS_BKP_ISSUE88;
    IF v_orig != v_bkp THEN
        RAISE_APPLICATION_ERROR(-20003, 'Respaldo inconsistente: ENVIOS=' || v_orig || ' BKP=' || v_bkp);
    END IF;
    DBMS_OUTPUT.PUT_LINE('[INFO] Respaldo ENVIOS_BKP_ISSUE88 con ' || v_bkp || ' filas.');
END;
/

ALTER TABLE USER_ENVIOS.ENVIOS ADD (
    sucursal_origen_id          NUMBER(19),
    servicio_id                 NUMBER(19),
    largo_declarado_cm          NUMBER(3),
    ancho_declarado_cm          NUMBER(3),
    alto_declarado_cm           NUMBER(3),
    peso_verificado_kg          NUMBER(10,2),
    largo_verificado_cm         NUMBER(3),
    ancho_verificado_cm         NUMBER(3),
    alto_verificado_cm          NUMBER(3),
    zona_estimada               VARCHAR2(30),
    factor_zona_estimado        NUMBER(4,2),
    tarifa_base_estimada        NUMBER(10,2),
    precio_kg_estimado          NUMBER(10,2),
    peso_facturable_estimado_kg NUMBER(10,2),
    precio_estimado_clp         NUMBER(12),
    zona_final                  VARCHAR2(30),
    factor_zona_final           NUMBER(4,2),
    tarifa_base_final           NUMBER(10,2),
    precio_kg_final             NUMBER(10,2),
    peso_facturable_final_kg    NUMBER(10,2),
    precio_final_clp            NUMBER(12),
    remitente_email             VARCHAR2(254 CHAR),
    verificado_por_email        VARCHAR2(320 CHAR),
    fecha_aceptacion            TIMESTAMP,
    CONSTRAINT chk_envios_peso_verificado CHECK (peso_verificado_kg IS NULL OR peso_verificado_kg > 0),
    CONSTRAINT chk_envios_medidas_decl CHECK (
        (largo_declarado_cm IS NULL AND ancho_declarado_cm IS NULL AND alto_declarado_cm IS NULL) OR
        (largo_declarado_cm BETWEEN 1 AND 300 AND ancho_declarado_cm BETWEEN 1 AND 300 AND alto_declarado_cm BETWEEN 1 AND 300)),
    CONSTRAINT chk_envios_medidas_verif CHECK (
        (largo_verificado_cm IS NULL AND ancho_verificado_cm IS NULL AND alto_verificado_cm IS NULL) OR
        (largo_verificado_cm BETWEEN 1 AND 300 AND ancho_verificado_cm BETWEEN 1 AND 300 AND alto_verificado_cm BETWEEN 1 AND 300))
);

CREATE INDEX USER_ENVIOS.idx_envios_remitente_email ON USER_ENVIOS.ENVIOS (remitente_email);

COMMENT ON COLUMN USER_ENVIOS.ENVIOS.remitente_email IS 'Correo del remitente normalizado (strip, NFC, minusculas); define la visibilidad del CLIENTE';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.precio_estimado_clp IS 'Total estimado por el catalogo al pre-registrar';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.precio_final_clp IS 'Total recalculado al aceptar con peso y medidas verificados';

DECLARE v_cols NUMBER; v_filas NUMBER; v_bkp NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cols FROM ALL_TAB_COLS
     WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS'
       AND column_name IN ('SUCURSAL_ORIGEN_ID','SERVICIO_ID','LARGO_DECLARADO_CM','ANCHO_DECLARADO_CM','ALTO_DECLARADO_CM',
           'PESO_VERIFICADO_KG','LARGO_VERIFICADO_CM','ANCHO_VERIFICADO_CM','ALTO_VERIFICADO_CM','ZONA_ESTIMADA',
           'FACTOR_ZONA_ESTIMADO','TARIFA_BASE_ESTIMADA','PRECIO_KG_ESTIMADO','PESO_FACTURABLE_ESTIMADO_KG',
           'PRECIO_ESTIMADO_CLP','ZONA_FINAL','FACTOR_ZONA_FINAL','TARIFA_BASE_FINAL','PRECIO_KG_FINAL',
           'PESO_FACTURABLE_FINAL_KG','PRECIO_FINAL_CLP','REMITENTE_EMAIL','VERIFICADO_POR_EMAIL','FECHA_ACEPTACION');
    IF v_cols != 24 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Se esperaban 24 columnas nuevas y hay ' || v_cols);
    END IF;
    SELECT COUNT(*) INTO v_filas FROM USER_ENVIOS.ENVIOS;
    SELECT COUNT(*) INTO v_bkp FROM USER_ENVIOS.ENVIOS_BKP_ISSUE88;
    IF v_filas != v_bkp THEN
        RAISE_APPLICATION_ERROR(-20005, 'Filas distintas tras migrar: ' || v_filas || ' frente a ' || v_bkp);
    END IF;
    DBMS_OUTPUT.PUT_LINE('[INFO] Migracion 12 correcta: ' || v_filas || ' filas.');
END;
/
COMMIT;
