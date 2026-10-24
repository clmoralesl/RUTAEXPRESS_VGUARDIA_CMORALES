# DICTAMEN TECNICO: CLAUDE -> ANTIGRAVITY
**Issue:** #57 - Generacion Automatica de Codigo de Seguimiento y Normalizacion de Direcciones de Envio
**Respuesta a:** `.claude_relevo.md` (Fase 1)
**Fase:** Fase 1 completada - pasa a Fase 2 (Implementacion, Antigravity)
**Alcance aprobado:** Opcion C con migracion directa

---

### DICTAMEN DE RELEVO: APROBADO

Decisiones del usuario incorporadas: normalizacion completa en Oracle (Opcion C), eventos con campos estructurados, y migracion directa (un solo script, sin periodo de doble formato) con respaldo previo.

No se verifico el contenido de `Envio.java` ni las rutas del BFF y del gateway. Esas comprobaciones figuran en la seccion 3.1.

---

## 1. Evaluacion de Arquitectura y Seguridad

### 1.1 Modelo de datos
- Tres niveles en `USER_ENVIOS`: `REGIONES`, `COMUNAS` (FK a region) y `ENVIOS` con FK a comuna para origen y destino.
- La region se obtiene por la comuna, sin columna redundante (3FN).
- Clave primaria con los **codigos oficiales CUT** (region `NUMBER(2)`, comuna `NUMBER(5)`), no secuencias, para que los scripts sean deterministas y reproducibles en cualquier entorno.

### 1.2 Contrato de API
- Cambio incompatible en `CrearEnvioRequest`: `direccionOrigen` y `direccionDestino` pasan a objetos estructurados con `idComuna`. Sin modo de compatibilidad.
- El servidor valida la FK. El cliente nunca envia nombres de comuna ni de region.
- El servidor ignora siempre cualquier `codigoSeguimiento` enviado por el cliente.

### 1.3 Contrato de eventos (Kafka y RabbitMQ)
- Solo aditivo: se agregan campos estructurados y se conserva `direccionOrigen` y `direccionDestino` como texto compuesto.
- `notificaciones` debe tolerar mensajes con y sin los campos nuevos.

### 1.4 Codigo de seguimiento
- Formato `RTX-YYYY-XXXXXX` aprobado (15 caracteres; la columna `VARCHAR2(50)` es suficiente).
- `XXXXXX`: alfabeto Crockford Base32 (`0123456789ABCDEFGHJKMNPQRSTVWXYZ`, sin I, L, O ni U). Espacio de 32^6 combinaciones por anio.
- Generacion con `SecureRandom`, no secuencia ni timestamp: el rastreo publico no autenticado haria enumerables los envios ajenos.
- Anio tomado de un `Clock` inyectado con zona `America/Santiago`.
- Compatible con Code 128 y QR.

### 1.5 Privacidad y seguridad
- El rastreo publico expone unicamente comuna y region, nunca calle ni numero.
- El DDL sobre Oracle ATP y el borrado de columnas requieren aprobacion explicita del usuario. Antigravity debe mostrar el script y esperar el visto bueno antes de ejecutarlo.
- Rate limiting del rastreo publico: fuera de alcance, registrar en backlog.

### 1.6 Orden de despliegue
Script SQL, luego `envios`, luego BFF (si aplica), luego `notificaciones` y por ultimo el frontend. El cambio de API es incompatible: entre `envios` y el frontend habra una ventana en la que la creacion de envios fallara con 400. Es aceptable en este proyecto, pero debe ejecutarse sin pausas.

---

## 2. Casos Borde Identificados

1. Filas existentes que no se puedan resolver a una comuna durante el backfill. No borrar ni inventar valores: listarlas y consultar al usuario.
2. Catalogo incompleto: validar con consultas que existan exactamente **16 regiones y 346 comunas**, y que todas las comunas tengan region.
3. Nombres con tildes y Ñ: la base debe estar en AL32UTF8 (valor por defecto de ATP). Verificar.
4. `LazyInitializationException` y N+1 al componer la direccion para eventos y respuestas. Resolver con `@EntityGraph` o `JOIN FETCH`, y componer el texto dentro de la transaccion.
5. Consumidor antiguo con mensajes nuevos y consumidor nuevo con mensajes antiguos: campos ausentes deben dar `null` sin excepcion.
6. `ddl-auto=validate` fallara si el script SQL no se aplico antes de arrancar la nueva imagen.
7. `idComuna` inexistente: responder 400 con mensaje claro, no 500.
8. Numero de calle: aceptar `S/N` explicito. Rechazar cadenas vacias o solo espacios.
9. Inyeccion: aplicar NFC, colapsar espacios, rechazar caracteres de control, y permitir solo letras, digitos, espacios y `. , ' - # / º °` en calle y complemento.
10. Rastreo de envios con codigos legados (por ejemplo `RE-2026-001`): no aplicar el regex estricto a la busqueda, solo a la generacion nueva.
11. Indices de las FK: Oracle no los crea automaticamente. Sin ellos, los `JOIN` y las operaciones sobre `COMUNAS` bloquean mas de lo necesario.
12. Doble clic en crear: al generar el codigo en servidor ya no hay idempotencia accidental. Deshabilitar el boton durante la peticion.
13. Colision de codigo de seguimiento: baja probabilidad pero real. Reintento acotado, con la restriccion `uk_envios_codigo_seguimiento` como respaldo ante condiciones de carrera.
14. Cambio de anio a las 23:59 del 31 de diciembre: el anio del codigo debe venir del `Clock`.
15. Publicacion de eventos: debe ocurrir despues del commit, para no notificar un codigo de una transaccion revertida.

---

## 3. Directivas de Implementacion para Antigravity

### 3.1 Verificaciones previas (sin modificar nada)
- Leer `Envio.java`, `EnvioResponse`, `SeguimientoPublicoResponse` y `EventoEnvioKafka`.
- Confirmar si `spring.jpa.open-in-view` esta activo y como el BFF reenvia el cuerpo (DTO tipado o paso directo).
- Revisar las rutas del API Gateway y las reglas RBAC del BFF para agregar el endpoint nuevo.
- Comprobar el charset de la base de datos (AL32UTF8).
- Verificar quien envia hoy `codigoSeguimiento` (BFF, frontend, pruebas, seeds).

### 3.2 Gestion Git (por repositorio)
Cada servicio y el frontend son repositorios independientes. Una rama por repositorio afectado:

| Repositorio | Rama |
|---|---|
| Raiz (scripts SQL) | `infra/normalizar-direcciones-envios-issue-57` |
| `ms-rutaexpress-envios` | `feat/generacion-codigo-normalizacion-direcciones-issue-57` |
| `ms-rutaexpress-notificaciones` | `feat/campos-direccion-estructurada-eventos-issue-57` |
| `rutaexpress-frontend` | `feat/formulario-direccion-estructurada-issue-57` |
| `ms-rutaexpress-bff` | Solo si las verificaciones lo exigen |

Ningun commit ni push sin aprobacion del usuario, que debe ver antes el resumen y el `git diff`.

### 3.3 Paso 1 - Scripts Oracle (repositorio raiz, `infra/oracle/`)

**`04_catalogo_geografico.sql`** - tablas y carga:

```sql
CREATE TABLE USER_ENVIOS.REGIONES (
    id_region  NUMBER(2)     NOT NULL,
    nombre     VARCHAR2(100) NOT NULL,
    CONSTRAINT pk_regiones PRIMARY KEY (id_region),
    CONSTRAINT uk_regiones_nombre UNIQUE (nombre)
);

CREATE TABLE USER_ENVIOS.COMUNAS (
    id_comuna  NUMBER(5)     NOT NULL,
    id_region  NUMBER(2)     NOT NULL,
    nombre     VARCHAR2(100) NOT NULL,
    CONSTRAINT pk_comunas PRIMARY KEY (id_comuna),
    CONSTRAINT fk_comunas_region FOREIGN KEY (id_region) REFERENCES USER_ENVIOS.REGIONES (id_region),
    CONSTRAINT uk_comunas_region_nombre UNIQUE (id_region, nombre)
);
CREATE INDEX USER_ENVIOS.idx_comunas_region ON USER_ENVIOS.COMUNAS (id_region);
```

- Cargar las 16 regiones y 346 comunas desde una fuente oficial (CUT de SUBDERE). Citar la fuente en un comentario del script.
- Al final, incluir las consultas de validacion `SELECT COUNT(*)` (16 y 346).

**`05_migracion_direcciones_envios.sql`** - en este orden:
1. Respaldo: `CREATE TABLE USER_ENVIOS.ENVIOS_BKP_ISSUE57 AS SELECT * FROM USER_ENVIOS.ENVIOS;` y verificar que el recuento coincida.
2. Agregar a `ENVIOS` como nullable: `calle_origen VARCHAR2(120)`, `numero_origen VARCHAR2(20)`, `complemento_origen VARCHAR2(80)`, `id_comuna_origen NUMBER(5)`, y los equivalentes `_destino`. Agregar las dos FK a `COMUNAS` y los indices `idx_envios_comuna_origen` e `idx_envios_comuna_destino`.
3. Backfill de filas existentes: parsear desde la derecha el texto antiguo y comparar la comuna sin tildes ni mayusculas.
4. Consulta de control con las filas sin resolver. **Detenerse y mostrarlas al usuario** antes de continuar.
5. Una vez resueltas todas: `ALTER TABLE ... MODIFY` a `NOT NULL` en calle, numero y comuna (origen y destino).
6. `ALTER TABLE ... DROP COLUMN direccion_origen` y `direccion_destino`.
7. Actualizar el `COMMENT` de `codigo_seguimiento` a `RTX-YYYY-XXXXXX`.

**`06_rollback_direcciones_issue57.sql`**: restaura `ENVIOS` desde `ENVIOS_BKP_ISSUE57` y elimina las tablas de catalogo.

**Scripts base:** actualizar `02_schema_envios.sql` y `03_data_envios.sql` para que un entorno nuevo nazca ya normalizado: catalogo primero, luego `ENVIOS` con columnas estructuradas, y las 8 filas de ejemplo reescritas con direcciones reales e `id_comuna`.

### 3.4 Paso 2 - `ms-rutaexpress-envios`

**Codigo de seguimiento**

```java
@Component
public class GeneradorCodigoSeguimiento {
    private static final char[] ALFABETO = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".toCharArray();
    private static final int LONGITUD = 6;
    private final SecureRandom random = new SecureRandom();
    private final Clock clock;

    public GeneradorCodigoSeguimiento(Clock clock) { this.clock = clock; }

    public String generar() {
        StringBuilder sb = new StringBuilder("RTX-")
                .append(Year.now(clock).getValue()).append('-');
        for (int i = 0; i < LONGITUD; i++) {
            sb.append(ALFABETO[random.nextInt(ALFABETO.length)]);
        }
        return sb.toString();
    }
}
```

- Registrar un bean `Clock` con `Clock.system(ZoneId.of("America/Santiago"))`.
- En `EnvioService.crear`: ignorar cualquier `codigoSeguimiento` entrante. Generar, validar con `existsByCodigoSeguimiento` y reintentar hasta 5 veces. Si se agotan, lanzar excepcion de servicio. La restriccion unica cubre la carrera.
- Marcar `codigoSeguimiento` con `@Column(updatable = false)` y excluirlo de todo DTO de actualizacion.
- Publicar eventos con `TransactionSynchronization.afterCommit` (o `@TransactionalEventListener(phase = AFTER_COMMIT)`).

**Direcciones**
- Entidades `Region` y `Comuna` de solo lectura (`@Immutable`). En `Envio`: `@ManyToOne(fetch = LAZY)` a `Comuna` para origen y destino, mas los campos planos `calleOrigen`, `numeroOrigen`, `complementoOrigen` y sus equivalentes de destino. Eliminar `direccionOrigen` y `direccionDestino`.
- DTO de entrada:

```java
public record DireccionRequest(
    @NotBlank @Size(max = 120) String calle,
    @NotBlank @Size(max = 20)  String numero,
    @Size(max = 80)            String complemento,
    @NotNull                   Integer idComuna) {}
```

  `CrearEnvioRequest` recibe `@Valid DireccionRequest origen, destino` y ya no recibe `codigoSeguimiento`.
- Servicio `NormalizadorDireccion`: aplica NFC, colapsa espacios, rechaza caracteres de control y valida los patrones del caso borde 9. Metodo `componer(envio, origen|destino)` que produce `"<calle> <numero>[, <complemento>], <Comuna>, <Region>"`, usado para el texto compuesto de respuestas y eventos.
- `EnvioResponse` anade objetos `origen` y `destino` con `calle`, `numero`, `complemento`, `idComuna`, `comuna` y `region`, y conserva `direccionOrigen` y `direccionDestino` compuestos para no obligar a reescribir toda la interfaz.
- Eliminar `extraerCiudad`. `SeguimientoPublicoResponse` toma comuna y region directamente de la relacion. Prohibido exponer calle y numero.
- Eventos: `EtiquetaPayload`, `TicketBodegaPayload` y `EventoEnvioKafka` anaden `calleOrigen`, `numeroOrigen`, `complementoOrigen`, `comunaOrigen`, `regionOrigen` y los equivalentes de destino (nombres, no ids). Conservan `direccionOrigen` y `direccionDestino` compuestos. Componer todo antes del `afterCommit`.
- Endpoint de catalogo para el frontend: `GET /api/envios/geografia/regiones`, que devuelve cada region con sus comunas. Solo lectura, cacheable.
- Repositorio: consultas con `@EntityGraph` para evitar N+1.

**Pruebas:** formato del codigo por regex `^RTX-\d{4}-[0-9A-HJKMNP-TV-Z]{6}$`, anio con `Clock` fijo, reintento ante colision simulada, codigo del cliente ignorado, normalizador, validaciones 400, composicion del texto, ausencia de calle en el rastreo publico y una prueba de repositorio contra el esquema.

### 3.5 Paso 3 - `ms-rutaexpress-notificaciones`
- Anadir los campos nuevos a `EtiquetaPayload` y `TicketBodegaPayload` (como opcionales). Confirmar que el deserializador ignora propiedades desconocidas.
- `EtiquetaService`: si hay campos estructurados, imprimir calle, comuna y region en lineas separadas. Si no, usar el texto compuesto.
- `TicketBodegaService`: anadir `comunaDestino` y `regionDestino` al JSON, que sirven para la clasificacion en bodega.
- Pruebas con mensajes antiguos (sin campos nuevos) y nuevos.

### 3.6 Paso 4 - BFF (solo lo que revelen las verificaciones)
- Ruta y rol para `/api/envios/geografia/regiones`.
- Que reenvie sin alterar los objetos `origen` y `destino`.
- Aplicar el mismo criterio a las reglas del API Gateway.

### 3.7 Paso 5 - `rutaexpress-frontend`
- `envios.service.ts`: modelos nuevos, metodo para el catalogo, y envio de los objetos `origen` y `destino`.
- `shipments`: quitar el input de codigo de seguimiento (leyenda "Se genera automaticamente al registrar el envio"). Formulario de direccion con Region -> Comuna dependiente -> Calle -> Numero (con opcion `S/N`) -> Complemento. Boton deshabilitado mientras la peticion esta en curso. Mostrar errores 400 junto al campo. Mostrar el codigo devuelto tras crear. En edicion, solo lectura.
- Actualizar `etiqueta-modal`, `auditoria.component.ts` (etiquetas de campos nuevos) y los datos de ejemplo de `auditoria.service.ts`.
- Actualizar los `.spec.ts` afectados.

### 3.8 Paso 6 - Verificacion y relevo de vuelta
- Compilar y ejecutar pruebas en cada repositorio (`mvn clean compile` y `mvn test`, `npm run build` y las pruebas del frontend). Ante un bloqueo tecnico, detenerse y reportar la causa raiz con los logs.
- Actualizar `.claude_relevo.md` a Fase 3 con el `git diff` de cada repositorio y los resultados de ejecucion.
- Incluir una **Matriz de impacto**:

| Repositorio | Archivos modificados | Script SQL asociado | Compilacion | Pruebas |
|---|---|---|---|---|
| (completar) | | | | |

- Incluir tambien los resultados de las consultas de validacion del catalogo y del backfill, y el recuento de `ENVIOS` antes y despues.

### 3.9 Orden obligatorio
Verificaciones, Paso 1 (con aprobacion del usuario antes de ejecutar el DDL), Paso 2, luego 3 y 4, y por ultimo el 5. No debe iniciarse un paso hasta que el anterior compile limpio.

---

## 4. Fuera de alcance (registrar en backlog)
- Cabecera `Idempotency-Key` para la creacion de envios.
- Rate limiting del rastreo publico.
- Eliminacion del texto compuesto de los eventos (`direccionOrigen` y `direccionDestino`) una vez que todos los consumidores usen los campos estructurados.
- Fuente unica del catalogo geografico en `ms-rutaexpress-catalogo`.
