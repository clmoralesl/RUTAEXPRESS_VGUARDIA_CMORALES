-- =============================================================================
-- Script: 05_data_catalogo.sql
-- Descripcion: Datos iniciales de servicios y flota vehicular PyME para RutaExpress
-- Proyecto: RutaExpress (Sprint 2 - Issue #19)
-- =============================================================================

-- Conectarse como USER_CATALOGO antes de ejecutar

INSERT INTO SERVICIOS_CATALOGO (
    CODIGO, NOMBRE, DESCRIPCION, TIPO_VEHICULO, 
    TARIFA_BASE, PRECIO_POR_KG, CAPACIDAD_MAXIMA_DIARIA, CAPACIDAD_DISPONIBLE, ACTIVO
) VALUES (
    'EXPRESS', 
    'Envio Express 24 Horas', 
    'Entrega garantizada en menos de 24 horas habiles en radio urbano metropolitano.', 
    'MOTO', 
    3990.00, 
    890.00, 
    50, 
    50, 
    1
);

INSERT INTO SERVICIOS_CATALOGO (
    CODIGO, NOMBRE, DESCRIPCION, TIPO_VEHICULO, 
    TARIFA_BASE, PRECIO_POR_KG, CAPACIDAD_MAXIMA_DIARIA, CAPACIDAD_DISPONIBLE, ACTIVO
) VALUES (
    'ESTANDAR', 
    'Envio Estandar 48-72 Horas', 
    'Distribucion economica para encomiendas no urgentes con cobertura interurbana.', 
    'FURGON', 
    2490.00, 
    490.00, 
    120, 
    120, 
    1
);

INSERT INTO SERVICIOS_CATALOGO (
    CODIGO, NOMBRE, DESCRIPCION, TIPO_VEHICULO, 
    TARIFA_BASE, PRECIO_POR_KG, CAPACIDAD_MAXIMA_DIARIA, CAPACIDAD_DISPONIBLE, ACTIVO
) VALUES (
    'MISMO_DIA', 
    'Entrega Mismo Dia (Same Day)', 
    'Despacho prioritario para compras realizadas antes de las 13:00 horas.', 
    'MOTO', 
    5490.00, 
    1190.00, 
    30, 
    30, 
    1
);

INSERT INTO SERVICIOS_CATALOGO (
    CODIGO, NOMBRE, DESCRIPCION, TIPO_VEHICULO, 
    TARIFA_BASE, PRECIO_POR_KG, CAPACIDAD_MAXIMA_DIARIA, CAPACIDAD_DISPONIBLE, ACTIVO
) VALUES (
    'CARGA_PESADA', 
    'Transporte de Carga Pesada y Paletizada', 
    'Transporte especializado para bultos mayores a 30 kg o mercaderia volumetrica.', 
    'CAMION', 
    14990.00, 
    350.00, 
    15, 
    15, 
    1
);

COMMIT;
