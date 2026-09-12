-- =============================================================================
-- Script: 02_schema_envios.sql
-- Descripción: Definición DDL de tablas, restricciones e índices para el esquema USER_ENVIOS.
-- Microservicio: ms-rutaexpress-envios
-- Proyecto: RutaExpress
-- Conexión: Diseñado para ejecutarse conectado como ADMIN (o como USER_ENVIOS).
-- =============================================================================

-- Cambiar el esquema activo de la sesión al usuario USER_ENVIOS
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- Eliminación previa en el esquema USER_ENVIOS si existe (limpieza limpia)
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE USER_ENVIOS.ENVIOS PURGE';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
         RAISE;
      END IF;
END;
/

-- Creación de la tabla ENVIOS en USER_ENVIOS
CREATE TABLE USER_ENVIOS.ENVIOS (
    id                  NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    codigo_seguimiento  VARCHAR2(50) NOT NULL,
    rut_remitente       VARCHAR2(20) NOT NULL,
    rut_destinatario    VARCHAR2(20) NOT NULL,
    direccion_origen    VARCHAR2(255) NOT NULL,
    direccion_destino   VARCHAR2(255) NOT NULL,
    peso_kg             NUMBER(10,2) NOT NULL,
    estado              VARCHAR2(30) NOT NULL,
    fecha_creacion      TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Restricciones Primarias y Únicas
    CONSTRAINT pk_envios PRIMARY KEY (id),
    CONSTRAINT uk_envios_codigo_seguimiento UNIQUE (codigo_seguimiento),
    
    -- Restricción Check: Peso positivo
    CONSTRAINT chk_envios_peso CHECK (peso_kg > 0),
    
    -- Restricción Check: Estados válidos del ciclo de vida del envío
    CONSTRAINT chk_envios_estado CHECK (
        estado IN ('CREADO', 'ACEPTADO', 'EN_BODEGA', 'EN_RUTA', 'ENTREGADO', 'CANCELADO')
    )
);

-- Comentarios documentales en la tabla y columnas
COMMENT ON TABLE USER_ENVIOS.ENVIOS IS 'Tabla principal que contiene el registro de envíos logísticos de RutaExpress';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.id IS 'Identificador único numérico autogenerado de la orden de envío';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.codigo_seguimiento IS 'Código único de rastreo / tracking (ej: RE-2026-001)';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.rut_remitente IS 'RUT o identificación de la persona/empresa que envía';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.rut_destinatario IS 'RUT o identificación del receptor del envío';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.direccion_origen IS 'Dirección completa de retiro u origen del envío';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.direccion_destino IS 'Dirección completa de entrega o destino del envío';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.peso_kg IS 'Peso total del paquete expresado en Kilogramos';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.estado IS 'Estado actual del ciclo de vida: CREADO, ACEPTADO, EN_BODEGA, EN_RUTA, ENTREGADO, CANCELADO';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.fecha_creacion IS 'Fecha y hora exacta de registro inicial en el sistema';
COMMENT ON COLUMN USER_ENVIOS.ENVIOS.fecha_actualizacion IS 'Fecha y hora del último cambio de estado o modificación';

-- Índices de alto rendimiento para búsquedas frecuentes en el esquema USER_ENVIOS
CREATE INDEX USER_ENVIOS.idx_envios_codigo_seguimiento ON USER_ENVIOS.ENVIOS (codigo_seguimiento);
CREATE INDEX USER_ENVIOS.idx_envios_rut_remitente ON USER_ENVIOS.ENVIOS (rut_remitente);
CREATE INDEX USER_ENVIOS.idx_envios_estado ON USER_ENVIOS.ENVIOS (estado);

COMMIT;
