-- =============================================================================
-- Script: 11_catalogo_sucursales_tarifas_issue83.sql
-- Descripcion: Esquema y sembrado para gestion de sucursales, tarifas por zona,
--              geografia de referencia y limites de servicios para RutaExpress.
-- Proyecto: RutaExpress (Issue #83 - Sub-issue A / Issue #87: Catalogo)
-- Esquema: USER_CATALOGO
--
-- NOTA IMPORTANTE: Este script no es idempotente. Si falla a mitad, ejecutar
--                  13_rollback_catalogo_issue83.sql y reintentar.
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_CATALOGO;

SET SERVEROUTPUT ON;

-- -----------------------------------------------------------------------------
-- 1. TABLA GEO_REGION (Replicacion minima de regiones para calculo de zonas)
-- -----------------------------------------------------------------------------
CREATE TABLE GEO_REGION (
    ID_REGION           NUMBER(4, 0) NOT NULL,
    NOMBRE              VARCHAR2(100) NOT NULL,
    ES_EXTREMA          NUMBER(1, 0) DEFAULT 0 NOT NULL,
    CONSTRAINT PK_GEO_REGION PRIMARY KEY (ID_REGION),
    CONSTRAINT CK_GEO_REGION_EXTREMA CHECK (ES_EXTREMA IN (0, 1))
);

COMMENT ON TABLE GEO_REGION IS 'Catalogo de referencia de regiones de Chile para clasificacion de zonas tarifarias';
COMMENT ON COLUMN GEO_REGION.ES_EXTREMA IS 'Indicador de zona geografica extrema (1: Extrema, 0: Regular)';

-- Sembrado de 16 regiones (Extremas: 15 Arica y Parinacota, 11 Aysen, 12 Magallanes)
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (1, 'Tarapacá', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (2, 'Antofagasta', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (3, 'Atacama', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (4, 'Coquimbo', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (5, 'Valparaíso', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (6, 'Región del Libertador Gral. Bernardo O''Higgins', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (7, 'Región del Maule', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (8, 'Región del Biobío', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (9, 'Región de la Araucanía', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (10, 'Región de los Lagos', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (11, 'Región Aisén del Gral. Carlos Ibañez del Campo', 1);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (12, 'Región de Magallanes y de la Antártica Chilena', 1);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (13, 'Región Metropolitana de Santiago', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (14, 'Región de los Ríos', 0);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (15, 'Arica y Parinacota', 1);
INSERT INTO GEO_REGION (ID_REGION, NOMBRE, ES_EXTREMA) VALUES (16, 'Región de Ñuble', 0);

-- -----------------------------------------------------------------------------
-- 2. TABLA GEO_REGION_LIMITROFE (Pares limitrofes ordenados: ID_REGION_A < ID_REGION_B)
-- -----------------------------------------------------------------------------
CREATE TABLE GEO_REGION_LIMITROFE (
    ID                  NUMBER(19, 0) GENERATED ALWAYS AS IDENTITY,
    ID_REGION_A         NUMBER(4, 0) NOT NULL,
    ID_REGION_B         NUMBER(4, 0) NOT NULL,
    CONSTRAINT PK_GEO_REGION_LIMITROFE PRIMARY KEY (ID),
    CONSTRAINT UQ_GEO_REGION_LIMITROFE UNIQUE (ID_REGION_A, ID_REGION_B),
    CONSTRAINT CK_GEO_LIMITROFE_ORDEN CHECK (ID_REGION_A < ID_REGION_B),
    CONSTRAINT FK_GEO_LIMITROFE_A FOREIGN KEY (ID_REGION_A) REFERENCES GEO_REGION (ID_REGION),
    CONSTRAINT FK_GEO_LIMITROFE_B FOREIGN KEY (ID_REGION_B) REFERENCES GEO_REGION (ID_REGION)
);

COMMENT ON TABLE GEO_REGION_LIMITROFE IS 'Relaciones de vecindad y adyacencia entre regiones para clasificacion limitrofe';

-- Sembrado de pares limitrofes
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (1, 2);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (1, 15);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (2, 3);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (3, 4);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (4, 5);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (5, 6);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (5, 13);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (6, 7);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (6, 13);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (7, 16);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (8, 9);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (8, 16);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (9, 14);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (10, 11);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (10, 14);
INSERT INTO GEO_REGION_LIMITROFE (ID_REGION_A, ID_REGION_B) VALUES (11, 12);

-- -----------------------------------------------------------------------------
-- 3. TABLA TARIFA_ZONA (Factores multiplicadores por zona geografica)
-- -----------------------------------------------------------------------------
CREATE TABLE TARIFA_ZONA (
    ID                  NUMBER(19, 0) GENERATED ALWAYS AS IDENTITY,
    ZONA                VARCHAR2(30) NOT NULL,
    FACTOR              NUMBER(4, 2) NOT NULL,
    DESCRIPCION         VARCHAR2(200),
    FECHA_ACTUALIZACION TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT PK_TARIFA_ZONA PRIMARY KEY (ID),
    CONSTRAINT UQ_TARIFA_ZONA UNIQUE (ZONA),
    CONSTRAINT CK_TARIFA_ZONA_FACTOR CHECK (FACTOR >= 1.00 AND FACTOR <= 5.00)
);

COMMENT ON TABLE TARIFA_ZONA IS 'Factores multiplicadores aplicables sobre la tarifa base segun clasificacion zonal';

-- Sembrado de 5 factores de zona
INSERT INTO TARIFA_ZONA (ZONA, FACTOR, DESCRIPCION) VALUES ('MISMA_COMUNA', 1.00, 'Origen y destino pertenecen a la misma comuna');
INSERT INTO TARIFA_ZONA (ZONA, FACTOR, DESCRIPCION) VALUES ('MISMA_REGION', 1.15, 'Origen y destino en distintas comunas de la misma region');
INSERT INTO TARIFA_ZONA (ZONA, FACTOR, DESCRIPCION) VALUES ('REGION_LIMITROFE', 1.35, 'Origen y destino en regiones adyacentes o limitrofes');
INSERT INTO TARIFA_ZONA (ZONA, FACTOR, DESCRIPCION) VALUES ('INTERREGIONAL', 1.70, 'Origen y destino en distintas regiones no adyacentes');
INSERT INTO TARIFA_ZONA (ZONA, FACTOR, DESCRIPCION) VALUES ('EXTREMA', 2.20, 'Origen o destino ubicado en zona geografica extrema');

-- -----------------------------------------------------------------------------
-- 4. TABLA SUCURSALES (Puntos fisicos habilitados para recepcion)
-- -----------------------------------------------------------------------------
CREATE TABLE SUCURSALES (
    ID                  NUMBER(19, 0) GENERATED ALWAYS AS IDENTITY,
    CODIGO              VARCHAR2(20) NOT NULL,
    NOMBRE              VARCHAR2(100) NOT NULL,
    CALLE               VARCHAR2(120) NOT NULL,
    NUMERO              VARCHAR2(20) NOT NULL,
    COMPLEMENTO         VARCHAR2(80),
    ID_COMUNA           NUMBER(6, 0) NOT NULL,
    HORARIO             VARCHAR2(200),
    ACTIVA              NUMBER(1, 0) DEFAULT 1 NOT NULL,
    FECHA_CREACION      TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FECHA_ACTUALIZACION TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT PK_SUCURSALES PRIMARY KEY (ID),
    CONSTRAINT UQ_SUCURSALES_CODIGO UNIQUE (CODIGO),
    CONSTRAINT CK_SUCURSAL_ACTIVA CHECK (ACTIVA IN (0, 1))
);

CREATE INDEX IDX_SUCURSALES_ACTIVA ON SUCURSALES (ACTIVA);
CREATE INDEX IDX_SUCURSALES_COMUNA ON SUCURSALES (ID_COMUNA);

COMMENT ON TABLE SUCURSALES IS 'Puntos de atencion presencial y recepcion de encomiendas de RutaExpress';

-- Sembrado de 5 sucursales iniciales
INSERT INTO SUCURSALES (CODIGO, NOMBRE, CALLE, NUMERO, COMPLEMENTO, ID_COMUNA, HORARIO, ACTIVA)
VALUES ('SUC-STGO', 'Santiago Centro', 'Calle Moneda', '1122', 'Oficina 101', 13101, 'Lun a Vie 09:00-19:00; Sab 10:00-14:00', 1);

INSERT INTO SUCURSALES (CODIGO, NOMBRE, CALLE, NUMERO, COMPLEMENTO, ID_COMUNA, HORARIO, ACTIVA)
VALUES ('SUC-PROV', 'Providencia', 'Av. Providencia', '2045', 'Local 4', 13123, 'Lun a Vie 09:00-19:00', 1);

INSERT INTO SUCURSALES (CODIGO, NOMBRE, CALLE, NUMERO, COMPLEMENTO, ID_COMUNA, HORARIO, ACTIVA)
VALUES ('SUC-VALP', 'Valparaíso', 'Calle Prat', '780', NULL, 5101, 'Lun a Vie 09:00-18:00', 1);

INSERT INTO SUCURSALES (CODIGO, NOMBRE, CALLE, NUMERO, COMPLEMENTO, ID_COMUNA, HORARIO, ACTIVA)
VALUES ('SUC-CONC', 'Concepción', 'Calle Barros Arana', '540', NULL, 8101, 'Lun a Vie 09:00-18:00', 1);

INSERT INTO SUCURSALES (CODIGO, NOMBRE, CALLE, NUMERO, COMPLEMENTO, ID_COMUNA, HORARIO, ACTIVA)
VALUES ('SUC-ANTO', 'Antofagasta', 'Calle Arturo Prat', '460', NULL, 2101, 'Lun a Vie 09:00-18:00', 1);

-- -----------------------------------------------------------------------------
-- 5. AMPLIACION DE LIMITES EN SERVICIOS_CATALOGO
-- -----------------------------------------------------------------------------
ALTER TABLE SERVICIOS_CATALOGO ADD (
    PESO_MAXIMO_KG      NUMBER(6, 2),
    LADO_MAXIMO_CM      NUMBER(5, 0),
    VOLUMEN_MAXIMO_CM3  NUMBER(10, 0),
    DIVISOR_VOLUMETRICO NUMBER(5, 0) DEFAULT 4000 NOT NULL,
    PLAZO_MIN_DIAS      NUMBER(2, 0),
    PLAZO_MAX_DIAS      NUMBER(2, 0),
    CONSTRAINT CK_SERVICIOS_PLAZOS CHECK (PLAZO_MIN_DIAS IS NULL OR PLAZO_MAX_DIAS IS NULL OR PLAZO_MIN_DIAS <= PLAZO_MAX_DIAS)
);

-- Actualizar limites y plazos para servicios existentes
UPDATE SERVICIOS_CATALOGO
SET PESO_MAXIMO_KG = 15.00,
    LADO_MAXIMO_CM = 60,
    VOLUMEN_MAXIMO_CM3 = 80000,
    DIVISOR_VOLUMETRICO = 4000,
    PLAZO_MIN_DIAS = 1,
    PLAZO_MAX_DIAS = 1
WHERE CODIGO = 'EXPRESS';

UPDATE SERVICIOS_CATALOGO
SET PESO_MAXIMO_KG = 30.00,
    LADO_MAXIMO_CM = 120,
    VOLUMEN_MAXIMO_CM3 = 200000,
    DIVISOR_VOLUMETRICO = 4000,
    PLAZO_MIN_DIAS = 2,
    PLAZO_MAX_DIAS = 4
WHERE CODIGO = 'ESTANDAR';

UPDATE SERVICIOS_CATALOGO
SET PESO_MAXIMO_KG = 10.00,
    LADO_MAXIMO_CM = 50,
    VOLUMEN_MAXIMO_CM3 = 50000,
    DIVISOR_VOLUMETRICO = 4000,
    PLAZO_MIN_DIAS = 0,
    PLAZO_MAX_DIAS = 1
WHERE CODIGO = 'MISMO_DIA';

UPDATE SERVICIOS_CATALOGO
SET PESO_MAXIMO_KG = 500.00,
    LADO_MAXIMO_CM = 250,
    VOLUMEN_MAXIMO_CM3 = 2000000,
    DIVISOR_VOLUMETRICO = 4000,
    PLAZO_MIN_DIAS = 3,
    PLAZO_MAX_DIAS = 7
WHERE CODIGO = 'CARGA_PESADA';

-- -----------------------------------------------------------------------------
-- 6. TABLA SERVICIO_COMUNA_EXCLUIDA (Restricciones operativas territoriales)
-- -----------------------------------------------------------------------------
CREATE TABLE SERVICIO_COMUNA_EXCLUIDA (
    ID                  NUMBER(19, 0) GENERATED ALWAYS AS IDENTITY,
    SERVICIO_ID         NUMBER(19, 0) NOT NULL,
    ID_COMUNA           NUMBER(6, 0) NOT NULL,
    CONSTRAINT PK_SERVICIO_COMUNA_EXCLUIDA PRIMARY KEY (ID),
    CONSTRAINT UQ_SERVICIO_COMUNA_EXCLUIDA UNIQUE (SERVICIO_ID, ID_COMUNA),
    CONSTRAINT FK_SERV_COMUNA_EXC_SERV FOREIGN KEY (SERVICIO_ID) REFERENCES SERVICIOS_CATALOGO (ID) ON DELETE CASCADE
);

CREATE INDEX IDX_SERV_COMUNA_EXC_SERV ON SERVICIO_COMUNA_EXCLUIDA (SERVICIO_ID);

COMMENT ON TABLE SERVICIO_COMUNA_EXCLUIDA IS 'Comunas insulares o de acceso restringido no cubiertas por determinados servicios';

-- Sembrado de comunas excluidas para todos los servicios actuales:
-- 5201: Isla de Pascua, 5104: Juan Fernandez, 12202: Antartica
INSERT INTO SERVICIO_COMUNA_EXCLUIDA (SERVICIO_ID, ID_COMUNA)
SELECT s.ID, c.COMUNA_ID
FROM SERVICIOS_CATALOGO s
CROSS JOIN (
    SELECT 5201 AS COMUNA_ID FROM DUAL
    UNION ALL SELECT 5104 FROM DUAL
    UNION ALL SELECT 12202 FROM DUAL
) c;

-- -----------------------------------------------------------------------------
-- 7. VERIFICACIONES DE CIERRE Y RECUENTO
-- -----------------------------------------------------------------------------
DECLARE
    v_regiones NUMBER;
    v_limitrofes NUMBER;
    v_tarifas NUMBER;
    v_sucursales NUMBER;
    v_excluidas NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_regiones FROM GEO_REGION;
    SELECT COUNT(*) INTO v_limitrofes FROM GEO_REGION_LIMITROFE;
    SELECT COUNT(*) INTO v_tarifas FROM TARIFA_ZONA;
    SELECT COUNT(*) INTO v_sucursales FROM SUCURSALES;
    SELECT COUNT(*) INTO v_excluidas FROM SERVICIO_COMUNA_EXCLUIDA;

    DBMS_OUTPUT.PUT_LINE('=== MIGRACION SCRIPT 11 EXITOSA ===');
    DBMS_OUTPUT.PUT_LINE('Regiones insertadas: ' || v_regiones || ' (Esperadas: 16)');
    DBMS_OUTPUT.PUT_LINE('Pares limitrofes insertados: ' || v_limitrofes || ' (Esperados: 16)');
    DBMS_OUTPUT.PUT_LINE('Factores de zona: ' || v_tarifas || ' (Esperados: 5)');
    DBMS_OUTPUT.PUT_LINE('Sucursales iniciales: ' || v_sucursales || ' (Esperadas: 5)');
    DBMS_OUTPUT.PUT_LINE('Comunas excluidas vinculadas: ' || v_excluidas || ' (Esperadas: >= 12)');

    IF v_regiones <> 16 OR v_limitrofes <> 16 OR v_tarifas <> 5 OR v_sucursales <> 5 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Recuento de datos de catalogo no coincide con lo esperado.');
    END IF;
END;
/

COMMIT;
