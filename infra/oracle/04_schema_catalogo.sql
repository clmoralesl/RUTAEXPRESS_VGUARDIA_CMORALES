-- =============================================================================
-- Script: 04_schema_catalogo.sql
-- Descripcion: Definicion del esquema y tabla SERVICIOS_CATALOGO para
--              ms-rutaexpress-catalogo en el esquema USER_CATALOGO.
-- Proyecto: RutaExpress (Sprint 2 - Issue #19)
-- =============================================================================

-- Conectarse como USER_CATALOGO antes de ejecutar

-- 1. Tabla de Catalogo de Servicios y Capacidad de Flota
CREATE TABLE SERVICIOS_CATALOGO (
    ID                      NUMBER(19, 0) GENERATED ALWAYS AS IDENTITY,
    CODIGO                  VARCHAR2(50) NOT NULL,
    NOMBRE                  VARCHAR2(100) NOT NULL,
    DESCRIPCION             VARCHAR2(500),
    TIPO_VEHICULO           VARCHAR2(50) NOT NULL,
    TARIFA_BASE             NUMBER(10, 2) NOT NULL,
    PRECIO_POR_KG           NUMBER(10, 2) NOT NULL,
    CAPACIDAD_MAXIMA_DIARIA NUMBER(6, 0) NOT NULL,
    CAPACIDAD_DISPONIBLE    NUMBER(6, 0) NOT NULL,
    ACTIVO                  NUMBER(1, 0) DEFAULT 1 NOT NULL,
    FECHA_CREACION          TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FECHA_ACTUALIZACION     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT PK_SERVICIOS_CATALOGO PRIMARY KEY (ID),
    CONSTRAINT UQ_SERVICIOS_CODIGO UNIQUE (CODIGO),
    CONSTRAINT CK_TARIFA_BASE_POSITIVA CHECK (TARIFA_BASE >= 0),
    CONSTRAINT CK_PRECIO_KG_POSITIVO CHECK (PRECIO_POR_KG >= 0),
    CONSTRAINT CK_CAPACIDAD_MAX_POSITIVA CHECK (CAPACIDAD_MAXIMA_DIARIA >= 0),
    CONSTRAINT CK_CAPACIDAD_DISP_RANGO CHECK (CAPACIDAD_DISPONIBLE >= 0 AND CAPACIDAD_DISPONIBLE <= CAPACIDAD_MAXIMA_DIARIA),
    CONSTRAINT CK_ACTIVO_BOOLEAN CHECK (ACTIVO IN (0, 1))
);

-- 2. Indices para busquedas frecuentes y consultas de disponibilidad
CREATE INDEX IDX_SERVICIOS_ACTIVO ON SERVICIOS_CATALOGO (ACTIVO);
CREATE INDEX IDX_SERVICIOS_VEHICULO ON SERVICIOS_CATALOGO (TIPO_VEHICULO);

COMMENT ON TABLE SERVICIOS_CATALOGO IS 'Catalogo de servicios logisticos de ultima milla, tarifas y control atomico de capacidad';
COMMENT ON COLUMN SERVICIOS_CATALOGO.CODIGO IS 'Codigo identificador unico del servicio (EXPRESS, ESTANDAR, MISMO_DIA, CARGA_PESADA)';
COMMENT ON COLUMN SERVICIOS_CATALOGO.CAPACIDAD_DISPONIBLE IS 'Cupos restantes para recepcion de envios en el dia';

COMMIT;
