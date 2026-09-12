-- =============================================================================
-- Script: 03_data_envios.sql
-- Descripción: Script DML de datos iniciales / registros dummy para el esquema USER_ENVIOS.
-- Microservicio: ms-rutaexpress-envios
-- Proyecto: RutaExpress
-- Conexión: Diseñado para ejecutarse conectado como ADMIN (o como USER_ENVIOS).
-- =============================================================================

-- Cambiar el esquema activo de la sesión al usuario USER_ENVIOS
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- Limpieza limpia de datos existentes en la tabla del esquema USER_ENVIOS
DELETE FROM USER_ENVIOS.ENVIOS;

-- Inserción de 8 registros dummy representativos del ciclo de vida logístico

-- 1. Estado CREADO: Envío recién registrado en la plataforma
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-001', '15678901-2', '18234567-8', 'Av. Providencia 1234, Providencia, Santiago', 'Calle Los Aromos 456, Maipú, Santiago', 2.50, 'CREADO'
);

-- 2. Estado ACEPTADO: Envío confirmado por el sistema y asignado
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-002', '12345678-9', '19876543-2', 'Av. Apoquindo 4500, Las Condes, Santiago', 'Pasaje El Roble 789, Pudahuel, Santiago', 1.20, 'ACEPTADO'
);

-- 3. Estado EN_BODEGA: Paquete recepcionado en el Hub central de distribución
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-003', '76543210-K', '14567890-1', 'Av. Vicuña Mackenna 890, Ñuñoa, Santiago', 'Av. Valparaíso 340, Viña del Mar, Valparaíso', 5.80, 'EN_BODEGA'
);

-- 4. Estado EN_RUTA: Paquete cargado en vehículo de ruta con destino final
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-004', '16789012-3', '17890123-4', 'Calle Brasil 560, Santiago Centro, Santiago', 'Av. Barros Luco 1200, San Antonio, Valparaíso', 3.10, 'EN_RUTA'
);

-- 5. Estado ENTREGADO: Envío finalizado con éxito en destino
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-005', '11223344-5', '13456789-0', 'Av. Libertador Bernardo O''Higgins 2100, Santiago', 'Av. Pedro de Valdivia 550, Concepción, Biobío', 0.75, 'ENTREGADO'
);

-- 6. Estado CANCELADO: Envío anulado por el cliente antes del despacho
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-006', '99887766-5', '16543210-9', 'Av. Grecia 3450, Macul, Santiago', 'Calle San Martín 890, Rancagua, O''Higgins', 4.00, 'CANCELADO'
);

-- 7. Estado EN_RUTA: Envío interregional hacia el norte
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-007', '14321987-6', '20123456-7', 'Av. Matta 780, Santiago Centro, Santiago', 'Av. Balmaceda 1500, Antofagasta, Antofagasta', 8.40, 'EN_RUTA'
);

-- 8. Estado ENTREGADO: Envío regional finalizado
INSERT INTO USER_ENVIOS.ENVIOS (
    codigo_seguimiento, rut_remitente, rut_destinatario, direccion_origen, direccion_destino, peso_kg, estado
) VALUES (
    'RE-2026-008', '10987654-3', '15432109-8', 'Calle Freire 450, San Bernardo, Santiago', 'Av. Alemania 1100, Temuco, Araucanía', 2.10, 'ENTREGADO'
);

-- Confirmación de transacciones
COMMIT;
