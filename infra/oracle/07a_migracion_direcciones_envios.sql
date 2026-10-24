-- =============================================================================
-- Script: 07a_migracion_direcciones_envios.sql
-- Descripcion: Fase A de migracion: Respaldo, nuevas columnas estructuradas,
--              claves foraneas, backfill y reconciliacion visual.
-- Proyecto: RutaExpress (Issue #57)
-- Esquema: USER_ENVIOS
-- Dependencia: Requiere ejecucion previa de 06_catalogo_geografico.sql
-- Pausa Obligatoria: Al finalizar este script, el operador/usuario DEBE revisar
--                   la consulta de reconciliacion visual antes de ejecutar 07b.
-- =============================================================================

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;

-- -----------------------------------------------------------------------------
-- PASO 1: Verificacion de respaldo previo (Evitar sobreescritura accidental)
-- -----------------------------------------------------------------------------
DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe 
    FROM ALL_TABLES 
    WHERE owner = 'USER_ENVIOS' AND table_name = 'ENVIOS_BKP_ISSUE57';

    IF v_existe > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ya existe la tabla USER_ENVIOS.ENVIOS_BKP_ISSUE57. Revisar su contenido antes de reejecutar la migracion.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 2: Verificacion previa de envios (Prevenir registros desconocidos sin backfill)
-- -----------------------------------------------------------------------------
DECLARE
    v_desconocidos NUMBER := 0;
    v_lista_codigos VARCHAR2(4000) := '';
BEGIN
    FOR r IN (
        SELECT codigo_seguimiento 
        FROM USER_ENVIOS.ENVIOS 
        WHERE codigo_seguimiento NOT IN (
            'RE-2026-001', 'RE-2026-002', 'RE-2026-003', 'RE-2026-004',
            'RE-2026-005', 'RE-2026-006', 'RE-2026-007', 'RE-2026-008',
            'RTX-297477',  'RTX-790284',  'RE-2026-010', 'RE-2026-011'
        )
    ) LOOP
        v_desconocidos := v_desconocidos + 1;
        v_lista_codigos := v_lista_codigos || r.codigo_seguimiento || ' ';
    END LOOP;

    IF v_desconocidos > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Se detectaron ' || v_desconocidos || ' envio(s) no catalogados para backfill automatico: ' || v_lista_codigos || '. Se requiere agregar su mapeo antes de proceder con el DDL.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 3: Creacion del respaldo de seguridad
-- -----------------------------------------------------------------------------
CREATE TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE57 AS 
SELECT * FROM USER_ENVIOS.ENVIOS;

SELECT COUNT(*) AS filas_originales FROM USER_ENVIOS.ENVIOS;
SELECT COUNT(*) AS filas_respaldo   FROM USER_ENVIOS.ENVIOS_BKP_ISSUE57;

-- -----------------------------------------------------------------------------
-- PASO 4: Agregar nuevas columnas estructuradas e indices de FK (como Nullable)
-- -----------------------------------------------------------------------------
ALTER TABLE USER_ENVIOS.ENVIOS ADD (
    calle_origen          VARCHAR2(120),
    numero_origen         VARCHAR2(20),
    complemento_origen    VARCHAR2(80),
    id_comuna_origen      NUMBER(5),
    calle_destino         VARCHAR2(120),
    numero_destino        VARCHAR2(20),
    complemento_destino   VARCHAR2(80),
    id_comuna_destino     NUMBER(5)
);

ALTER TABLE USER_ENVIOS.ENVIOS ADD CONSTRAINT fk_envios_comuna_origen
    FOREIGN KEY (id_comuna_origen) REFERENCES USER_ENVIOS.COMUNAS (id_comuna);

ALTER TABLE USER_ENVIOS.ENVIOS ADD CONSTRAINT fk_envios_comuna_destino
    FOREIGN KEY (id_comuna_destino) REFERENCES USER_ENVIOS.COMUNAS (id_comuna);

CREATE INDEX USER_ENVIOS.idx_envios_comuna_origen ON USER_ENVIOS.ENVIOS (id_comuna_origen);
CREATE INDEX USER_ENVIOS.idx_envios_comuna_destino ON USER_ENVIOS.ENVIOS (id_comuna_destino);

-- -----------------------------------------------------------------------------
-- PASO 5: Backfill de filas legadas catalogadas
-- -----------------------------------------------------------------------------

-- 1. RE-2026-001 (Providencia -> Maipu)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Providencia', numero_origen = '1234', complemento_origen = NULL, id_comuna_origen = 13123,
    calle_destino = 'Calle Los Aromos', numero_destino = '456', complemento_destino = NULL, id_comuna_destino = 13119
WHERE codigo_seguimiento = 'RE-2026-001';

-- 2. RE-2026-002 (Las Condes -> Pudahuel)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Apoquindo', numero_origen = '4500', complemento_origen = NULL, id_comuna_origen = 13114,
    calle_destino = 'Pasaje El Roble', numero_destino = '789', complemento_destino = NULL, id_comuna_destino = 13124
WHERE codigo_seguimiento = 'RE-2026-002';

-- 3. RE-2026-003 (Nunoa -> Vina del Mar)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Vicuña Mackenna', numero_origen = '890', complemento_origen = NULL, id_comuna_origen = 13120,
    calle_destino = 'Av. Valparaíso', numero_destino = '340', complemento_destino = NULL, id_comuna_destino = 5109
WHERE codigo_seguimiento = 'RE-2026-003';

-- 4. RE-2026-004 (Santiago Centro -> San Antonio)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Calle Brasil', numero_origen = '560', complemento_origen = NULL, id_comuna_origen = 13101,
    calle_destino = 'Av. Barros Luco', numero_destino = '1200', complemento_destino = NULL, id_comuna_destino = 5601
WHERE codigo_seguimiento = 'RE-2026-004';

-- 5. RE-2026-005 (Santiago Centro -> Concepcion)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Libertador Bernardo O''Higgins', numero_origen = '2100', complemento_origen = NULL, id_comuna_origen = 13101,
    calle_destino = 'Av. Pedro de Valdivia', numero_destino = '550', complemento_destino = NULL, id_comuna_destino = 8101
WHERE codigo_seguimiento = 'RE-2026-005';

-- 6. RE-2026-006 (Macul -> Rancagua)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Grecia', numero_origen = '3450', complemento_origen = NULL, id_comuna_origen = 13118,
    calle_destino = 'Calle San Martín', numero_destino = '890', complemento_destino = NULL, id_comuna_destino = 6101
WHERE codigo_seguimiento = 'RE-2026-006';

-- 7. RE-2026-007 (Santiago Centro -> Antofagasta)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Matta', numero_origen = '780', complemento_origen = NULL, id_comuna_origen = 13101,
    calle_destino = 'Av. Balmaceda', numero_destino = '1500', complemento_destino = NULL, id_comuna_destino = 2101
WHERE codigo_seguimiento = 'RE-2026-007';

-- 8. RE-2026-008 (San Bernardo -> Temuco)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Calle Freire', numero_origen = '450', complemento_origen = NULL, id_comuna_origen = 13401,
    calle_destino = 'Av. Alemania', numero_destino = '1100', complemento_destino = NULL, id_comuna_destino = 9101
WHERE codigo_seguimiento = 'RE-2026-008';

-- 9. RTX-297477 (Providencia -> Concepcion)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Providencia', numero_origen = '1234', complemento_origen = NULL, id_comuna_origen = 13123,
    calle_destino = 'Calle San Martin', numero_destino = '567', complemento_destino = NULL, id_comuna_destino = 8101
WHERE codigo_seguimiento = 'RTX-297477';

-- 10. RTX-790284 (Providencia -> Concepcion)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Av. Providencia', numero_origen = '1234', complemento_origen = NULL, id_comuna_origen = 13123,
    calle_destino = 'Calle San Martin', numero_destino = '567', complemento_destino = NULL, id_comuna_destino = 8101
WHERE codigo_seguimiento = 'RTX-790284';

-- 11. RE-2026-010 (Prat 801, Antofagasta -> Liagora 560, Maipu)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Calle Prat', numero_origen = '801', complemento_origen = NULL, id_comuna_origen = 2101,
    calle_destino = 'Calle Liagora', numero_destino = '560', complemento_destino = NULL, id_comuna_destino = 13119
WHERE codigo_seguimiento = 'RE-2026-010';

-- 12. RE-2026-011 (Prat 801, Antofagasta -> Ecuador 54, Estacion Central)
UPDATE USER_ENVIOS.ENVIOS
SET calle_origen = 'Calle Prat', numero_origen = '801', complemento_origen = NULL, id_comuna_origen = 2101,
    calle_destino = 'Av. Ecuador', numero_destino = '54', complemento_destino = NULL, id_comuna_destino = 13106
WHERE codigo_seguimiento = 'RE-2026-011';

COMMIT;

-- -----------------------------------------------------------------------------
-- PASO 6: Comprobacion de cobertura de backfill (Abortar si hay nulos)
-- -----------------------------------------------------------------------------
DECLARE
    v_nulos NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_nulos
    FROM USER_ENVIOS.ENVIOS
    WHERE id_comuna_origen IS NULL OR id_comuna_destino IS NULL;

    IF v_nulos > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Existen ' || v_nulos || ' filas con comuna nula tras el backfill. No se puede proceder con el cierre de la migracion.');
    END IF;
END;
/

-- -----------------------------------------------------------------------------
-- PASO 7: Consulta de reconciliacion visual con evaluacion automatica de coincidencia
-- -----------------------------------------------------------------------------
SELECT 
    e.id,
    e.codigo_seguimiento,
    e.direccion_origen AS origen_legacy,
    (e.calle_origen || ' ' || e.numero_origen || ', ' || co.nombre) AS origen_nuevo,
    CASE WHEN INSTR(UPPER(e.direccion_origen), UPPER(e.calle_origen)) > 0
          AND INSTR(UPPER(e.direccion_origen), UPPER(co.nombre)) > 0
         THEN 'OK' ELSE 'REVISAR' END AS coincide_origen,
    e.direccion_destino AS destino_legacy,
    (e.calle_destino || ' ' || e.numero_destino || ', ' || cd.nombre) AS destino_nuevo,
    CASE WHEN INSTR(UPPER(e.direccion_destino), UPPER(e.calle_destino)) > 0
          AND INSTR(UPPER(e.direccion_destino), UPPER(cd.nombre)) > 0
         THEN 'OK' ELSE 'REVISAR' END AS coincide_destino
FROM USER_ENVIOS.ENVIOS e
JOIN USER_ENVIOS.COMUNAS co ON co.id_comuna = e.id_comuna_origen
JOIN USER_ENVIOS.COMUNAS cd ON cd.id_comuna = e.id_comuna_destino
ORDER BY e.id;

PROMPT =============================================================================
PROMPT FASE A COMPLETADA EXITOSAMENTE.
PROMPT REVISAR LOS RESULTADOS ANTERIORES.
PROMPT SI TODAS LAS FILAS TIENEN 'OK' O LAS DIFERENCIAS SON ACEPTABLES, PROCEDER CON:
PROMPT @07b_migracion_direcciones_envios_cierre.sql
PROMPT =============================================================================
