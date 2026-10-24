-- =============================================================================
-- Script: 03_data_envios.sql
-- Descripción: Script DML de datos iniciales / registros representativos para el esquema USER_ENVIOS.
-- Microservicio: ms-rutaexpress-envios
-- Proyecto: RutaExpress (Normalizado Issue #57)
-- Conexión: Diseñado para ejecutarse conectado como ADMIN (o como USER_ENVIOS).
-- Dependencia: Requiere previa ejecucion de 06_catalogo_geografico.sql y 02_schema_envios.sql
-- =============================================================================

ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- Limpieza limpia de datos existentes en la tabla del esquema USER_ENVIOS
DELETE FROM USER_ENVIOS.ENVIOS;

-- Inserción de 8 registros representativos del ciclo de vida logístico con direcciones normalizadas

-- 1. Estado CREADO: Envío recién registrado (Providencia -> Maipu)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000001', '15678901-2', '18234567-8',
    'Av. Providencia', '1234', 'Oficina 402', 13123,
    'Calle Los Aromos', '456', NULL, 13119,
    2.50, 'CREADO'
);

-- 2. Estado ACEPTADO: Envío confirmado y clasificado (Las Condes -> Pudahuel)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000002', '12345678-9', '19876543-2',
    'Av. Apoquindo', '4500', 'Piso 12', 13114,
    'Pasaje El Roble', '789', NULL, 13124,
    1.20, 'ACEPTADO'
);

-- 3. Estado EN_BODEGA: Paquete en Hub central (Nunoa -> Vina del Mar)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000003', '76543210-K', '14567890-1',
    'Av. Vicuña Mackenna', '890', NULL, 13120,
    'Av. Valparaíso', '340', 'Local 5', 5109,
    5.80, 'EN_BODEGA'
);

-- 4. Estado EN_RUTA: En vehiculo interregional (Santiago Centro -> San Antonio)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000004', '16789012-3', '17890123-4',
    'Calle Brasil', '560', NULL, 13101,
    'Av. Barros Luco', '1200', NULL, 5601,
    3.10, 'EN_RUTA'
);

-- 5. Estado ENTREGADO: Entregado exitosamente (Santiago Centro -> Concepcion)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000005', '11223344-5', '13456789-0',
    'Av. Libertador Bernardo O''Higgins', '2100', 'Depto 301', 13101,
    'Av. Pedro de Valdivia', '550', NULL, 8101,
    0.75, 'ENTREGADO'
);

-- 6. Estado CANCELADO: Anulado antes del despacho (Macul -> Rancagua)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000006', '99887766-5', '16543210-9',
    'Av. Grecia', '3450', NULL, 13118,
    'Calle San Martín', '890', NULL, 6101,
    4.00, 'CANCELADO'
);

-- 7. Estado EN_RUTA: Ruta norte (Santiago Centro -> Antofagasta)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000007', '14321987-6', '20123456-7',
    'Av. Matta', '780', NULL, 13101,
    'Av. Balmaceda', '1500', 'Torre A Depto 102', 2101,
    8.40, 'EN_RUTA'
);

-- 8. Estado ENTREGADO: Ruta sur (San Bernardo -> Temuco)
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario,
    calle_origen, numero_origen, complemento_origen, id_comuna_origen,
    calle_destino, numero_destino, complemento_destino, id_comuna_destino,
    peso_kg, estado
) VALUES (
    'RTX-2026-000008', '10987654-3', '15432109-8',
    'Calle Freire', '450', NULL, 13401,
    'Av. Alemania', '1100', NULL, 9101,
    2.10, 'ENTREGADO'
);

COMMIT;
