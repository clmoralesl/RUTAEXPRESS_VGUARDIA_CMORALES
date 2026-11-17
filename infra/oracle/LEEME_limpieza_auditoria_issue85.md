# Procedimiento de Limpieza de Eventos de Prueba en Auditoria (Issue #85)

## 1. Contexto, Causa Raiz y Solucion

### Problema
El endpoint `/api/auditoria/envios/{id}` y la pantalla de Auditoria Forense presentaban eventos mezclados pertenecientes a envios diferentes. Al consultar el historial del envio con ID 4, por ejemplo, aparecian tanto eventos legitimos de produccion como decenas de eventos de pruebas automatizadas anteriores.

### Causa Raiz
1. La consulta del historial se realizaba unicamente mediante el identificador numerico secuencial `envio_id`.
2. Los eventos con IDs 1 a 4 y codigos `RTX-2026-*` se originaron en las pruebas de integracion de `ms-rutaexpress-envios` que publicaban en el Kafka compartido (corregidas en el issue #69).
3. Los eventos con prefijos `RE-AUDIT-*` y `RE-ANL-TEST-*` provienen de las pruebas de integracion de `ms-rutaexpress-auditoria` y `ms-rutaexpress-reportes` (corregidas en este issue #85 mediante exclusion de grupos Surefire).
4. Los eventos con prefijos `RE-LIVE-*` y `RE-KAFKA-*` corresponden a pruebas manuales ejecutadas el 18 de octubre.
5. Al coincidir los `envio_id` generados localmente con los de la base de datos Oracle Cloud, el historial consolidaba eventos de origenes dispares bajo un mismo identificador numerico.

### Solucion
1. **Aislamiento de Pruebas:** Se etiquetaron las pruebas de integracion externa (`@Tag("integracion-externa")`) en `ms-rutaexpress-auditoria` y `ms-rutaexpress-reportes`, excluyendolas del ciclo de vida estandar de Maven (`mvn test`).
2. **Saneamiento en Oracle:** Se proporcionan scripts SQL controlados para diagnosticar, respaldar y purgar unicamente los eventos huerfanos o inconsistentes, preservando intactos los eventos reales cuyo par (`envio_id`, `codigo_seguimiento`) existe en la tabla `USER_ENVIOS.ENVIOS`.
3. **Endurecimiento de Consulta:** La API y el frontend consultan ahora por el par (`envio_id`, `codigo_seguimiento`). Si una consulta sin codigo detecta ambiguedad (multiples codigos bajo un mismo `envio_id`), responde HTTP 409 Conflict con la lista de codigos para evitar mezclas silenciosas.
4. **Deteccion Preventiva:** Se incorporaron metricas y advertencias en el registro ante eventos inconsistentes entrantes, sin descartarlos de la base inmutable.

---

## 2. Secuencia de Ejecucion y Despliegue (D12)

> **Advertencia (D12):** No desplegar la nueva version de auditoria antes de completar el paso 15: los envios con eventos de varios codigos (ids 1 a 4) responderian 409 y el frontend anterior mostraria datos de contingencia.

La ejecucion debe seguir estrictamente este orden:

1. **Aislamiento de pruebas (D1):** Fusionar el cambio de etiquetas y configuracion Maven en auditoria y reportes antes de ejecutar cualquier suite de pruebas.
2. **Detener el servicio de auditoria:** Detener temporalmente el contenedor o proceso de `ms-rutaexpress-auditoria` para garantizar que no ingresen nuevos eventos durante la limpieza.
3. **Ejecutar diagnostico preliminar (Paso 14):**
   - Conectarse como usuario `ADMIN` mediante SQLcl o SQL Developer.
   - Ejecutar `14_diagnostico_eventos_prueba_auditoria_issue85.sql`.
   - Guardar el informe de salida completo para adjuntarlo a las evidencias del PR.
   - Verificar que la seccion `CODIGO_EXISTE_CON_OTRO_ID` reporte 0 registros (si existiera alguno, detenerse y analizar antes de limpiar).
4. **Ejecutar script de limpieza con respaldo (Paso 15):**
   - Conectarse como `ADMIN`.
   - Ejecutar `15_limpieza_eventos_prueba_auditoria_issue85.sql`.
   - Guardar la salida con los recuentos iniciales y finales.
5. **Desplegar y arrancar nueva version de `ms-rutaexpress-auditoria`:**
   - Iniciar el servicio con el endpoint endurecido (soporte de `codigoSeguimiento` y respuesta 409).
6. **Saneamiento y reinicio de `ms-rutaexpress-reportes` (D8):**
   - Verificar si en el archivo `.env` del entorno existe la variable `SPRING_DATASOURCE_URL` redefiniendo la conexion.
   - Si utiliza la configuracion estandar (H2 en memoria), reiniciar el contenedor de reportes (`docker compose restart ms-rutaexpress-reportes`) para inicializar el estado analitico limpio.
7. **Desplegar `rutaexpress-frontend`:**
   - Publicar la nueva version de la aplicacion web con busqueda por servidor y consulta por par.

---

## 3. Procedimiento de Prueba del Rollback

Para validar que el mecanismo de restauracion de emergencia funciona correctamente en un entorno de pruebas:

1. Detener `ms-rutaexpress-auditoria` tambien durante el rollback para evitar que ingresen nuevos eventos mientras se reinsertan los datos respaldados.
2. Ejecutar `15_limpieza_eventos_prueba_auditoria_issue85.sql` (creara el respaldo y realizara la purga).
3. Ejecutar inmediatamente `16_rollback_limpieza_auditoria_issue85.sql`.
4. Validar que el recuento final de `HISTORIAL_AUDITORIA` coincida exactamente con el de `HISTORIAL_AUDITORIA_BKP_ISSUE85`.
5. Eliminar el respaldo de prueba:
   ```sql
   DROP TABLE USER_AUDITORIA.HISTORIAL_AUDITORIA_BKP_ISSUE85 PURGE;
   ```
6. Volver a ejecutar `15_limpieza_eventos_prueba_auditoria_issue85.sql` para dejar la base en estado saneado definitivo.

---

## 4. Consideraciones de Topicos Kafka y DLQ (D10)

Los topicos `audit.timeline`, `shipments.events.DLT` y `audit.timeline.DLT` estan definidos en la infraestructura de Kafka pero actualmente no poseen consumidores ni productores activos en el codigo. Cuando un requerimiento futuro incorpore mensajeria sobre dichos topicos, debera aplicar las mismas validaciones de consistencia implementadas en el consumidor de auditoria.

---

## 5. Plantilla de Registro de Recuentos (Para Evidencias)

Completar esta tabla con los resultados obtenidos al ejecutar los scripts 14 y 15:

| Metrica / Indicador | Valor Previo (Diagnostico 14) | Valor Posterior (Limpieza 15) | Diferencia / Observacion |
| :--- | :--- | :--- | :--- |
| Total de eventos en auditoria | | | |
| Eventos clasificados como CONSISTENTES | | | |
| Eventos clasificados como HUERFANOS/PRUEBA | | | |
| Eventos CODIGO_EXISTE_CON_OTRO_ID | 0 | 0 | Debe ser 0 |
| Total de envios en ENVIOS con eventos | | | |
| Filas respaldadas en BKP_ISSUE85 | N/A | | |
| Filas purgadas de HISTORIAL_AUDITORIA | N/A | | |
| Reportes: fuente de datos (.env SPRING_DATASOURCE_URL) y resultado del reinicio | | | |
