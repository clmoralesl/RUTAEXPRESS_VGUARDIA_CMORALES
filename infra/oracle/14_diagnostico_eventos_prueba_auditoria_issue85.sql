-- =============================================================================
-- Script: 14_diagnostico_eventos_prueba_auditoria_issue85.sql
-- Descripcion: Diagnostico de solo lectura para clasificar eventos de prueba y
--              analizar la contaminacion en el historial de auditoria.
-- Proyecto: RutaExpress (Issue #85)
-- Esquema: USER_AUDITORIA / USER_ENVIOS
-- Conexion: Disenado para ejecutarse conectado como ADMIN.
-- Regla: Solo lectura (sin DDL, DML ni COMMIT). Forma parte de la correccion unica y excepcional del issue #85 sobre una tabla inmutable por diseno.
-- =============================================================================

SET SERVEROUTPUT ON;

-- 1. Total de eventos en auditoria y total de envios registrados en ENVIOS
SELECT 'TOTAL_EVENTOS_AUDITORIA' AS metrica, COUNT(*) AS total FROM USER_AUDITORIA.HISTORIAL_AUDITORIA
UNION ALL
SELECT 'TOTAL_ENVIOS_BASE' AS metrica, COUNT(*) AS total FROM USER_ENVIOS.ENVIOS;

-- 2. Clasificacion de eventos segun consistencia con la tabla ENVIOS
SELECT clasificacion, COUNT(*) AS cantidad
FROM (
    SELECT
        CASE
            WHEN EXISTS (
                SELECT 1 FROM USER_ENVIOS.ENVIOS e
                WHERE e.id = h.envio_id AND e.codigo_seguimiento = h.codigo_seguimiento
            ) THEN 'CONSISTENTE'
            WHEN EXISTS (
                SELECT 1 FROM USER_ENVIOS.ENVIOS e
                WHERE e.codigo_seguimiento = h.codigo_seguimiento AND e.id != h.envio_id
            ) THEN 'CODIGO_EXISTE_CON_OTRO_ID'
            WHEN EXISTS (
                SELECT 1 FROM USER_ENVIOS.ENVIOS e
                WHERE e.id = h.envio_id AND e.codigo_seguimiento != h.codigo_seguimiento
            ) THEN 'ID_EXISTE_CON_OTRO_CODIGO'
            ELSE 'HUERFANO'
        END AS clasificacion
    FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
)
GROUP BY clasificacion
ORDER BY cantidad DESC;

-- 3. Detalle de eventos con CODIGO_EXISTE_CON_OTRO_ID (anomalia critica para D2)
SELECT
    h.id AS historial_id,
    h.evento_id,
    h.envio_id AS envio_id_auditoria,
    h.codigo_seguimiento,
    h.fecha_evento,
    e.id AS envio_id_real_envios
FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
JOIN USER_ENVIOS.ENVIOS e ON e.codigo_seguimiento = h.codigo_seguimiento AND e.id != h.envio_id
ORDER BY h.fecha_evento ASC;

-- 4. Cantidad de eventos y codigos distintos por envio_id en auditoria
SELECT
    h.envio_id,
    COUNT(*) AS total_eventos,
    COUNT(DISTINCT h.codigo_seguimiento) AS codigos_distintos
FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
GROUP BY h.envio_id
ORDER BY codigos_distintos DESC, total_eventos DESC;

-- 5. Distribucion de codigos por patron de prefijo
SELECT
    NVL(REGEXP_SUBSTR(h.codigo_seguimiento, '^[A-Za-z]+-[A-Za-z0-9]+'), 'OTRO') AS prefijo,
    COUNT(*) AS total_eventos,
    COUNT(DISTINCT h.codigo_seguimiento) AS codigos_unicos
FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
GROUP BY NVL(REGEXP_SUBSTR(h.codigo_seguimiento, '^[A-Za-z]+-[A-Za-z0-9]+'), 'OTRO')
ORDER BY total_eventos DESC;

-- 6. Envios en ENVIOS sin ningun evento consistente en auditoria (C23)
SELECT
    e.id AS envio_id,
    e.codigo_seguimiento,
    e.estado_actual,
    e.fecha_creacion
FROM USER_ENVIOS.ENVIOS e
WHERE NOT EXISTS (
    SELECT 1 FROM USER_AUDITORIA.HISTORIAL_AUDITORIA h
    WHERE h.envio_id = e.id AND h.codigo_seguimiento = e.codigo_seguimiento
)
ORDER BY e.id ASC;

-- 7. Comentario final:
-- El microservicio ms-rutaexpress-reportes utiliza base de datos analitica local H2 en memoria.
-- Por definicion de diseno (D8), reportes no persiste en Oracle Cloud; su limpieza se realiza reiniciando el servicio.
