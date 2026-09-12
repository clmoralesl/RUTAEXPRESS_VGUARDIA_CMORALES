-- =============================================================================
-- Script: 01_crear_esquemas.sql
-- Descripción: Aprovisionamiento de Usuarios/Esquemas Oracle para la estrategia
--              Database-per-Service en Oracle Cloud DB / Autonomous Database.
-- Proyecto: RutaExpress
-- Ejecución: Requiere privilegios de Administrador (ADMIN / SYSTEM).
-- =============================================================================

-- 1. Esquema Principal Sprint 1: USER_ENVIOS (Microservicio ms-rutaexpress-envios)
CREATE USER USER_ENVIOS IDENTIFIED BY "PLACEHOLDER_CONTRASEÑA";

-- Otorgar cuota de almacenamiento y privilegios esenciales a USER_ENVIOS
ALTER USER USER_ENVIOS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO USER_ENVIOS;
GRANT CREATE TABLE TO USER_ENVIOS;
GRANT CREATE SEQUENCE TO USER_ENVIOS;
GRANT CREATE TRIGGER TO USER_ENVIOS;
GRANT CREATE VIEW TO USER_ENVIOS;
GRANT CREATE PROCEDURE TO USER_ENVIOS;

-- 2. Esquemas Preparados Sprint 2: USER_CATALOGO (Microservicio ms-rutaexpress-catalogo)
CREATE USER USER_CATALOGO IDENTIFIED BY "PLACEHOLDER_CONTRASEÑA";
ALTER USER USER_CATALOGO QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO USER_CATALOGO;
GRANT CREATE TABLE TO USER_CATALOGO;
GRANT CREATE SEQUENCE TO USER_CATALOGO;
GRANT CREATE TRIGGER TO USER_CATALOGO;
GRANT CREATE VIEW TO USER_CATALOGO;

-- 3. Esquemas Preparados Sprint 2: USER_AUDITORIA (Microservicio ms-rutaexpress-auditoria)
CREATE USER USER_AUDITORIA IDENTIFIED BY "PLACEHOLDER_CONTRASEÑA";
ALTER USER USER_AUDITORIA QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO USER_AUDITORIA;
GRANT CREATE TABLE TO USER_AUDITORIA;
GRANT CREATE SEQUENCE TO USER_AUDITORIA;
GRANT CREATE TRIGGER TO USER_AUDITORIA;
GRANT CREATE VIEW TO USER_AUDITORIA;

-- Fin de creación de usuarios/esquemas
COMMIT;
