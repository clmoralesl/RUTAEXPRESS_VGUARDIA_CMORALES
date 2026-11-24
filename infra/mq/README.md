# Infraestructura RabbitMQ - RutaExpress (Issue #17)

Broker de mensajeria local para los comandos asincronos de RutaExpress (correo, ticket de bodega y etiqueta).

---

## 1. Arquitectura y Puertos

- Imagen: `rabbitmq:3-management-alpine`, contenedor `rutaexpress-rabbitmq`, red `rutaexpress-net`.
- Puerto `5672`: protocolo AMQP (conexiones de los microservicios).
- Puerto `15672`: consola de administracion y API HTTP.
- Archivos: `compose.yml`, `rabbitmq.conf` y `definitions.json` (topologia cargada al arrancar).

### Credenciales de Acceso
Las credenciales locales son las definidas en `compose.yml` para el entorno de desarrollo. No se reproducen en este documento.

---

## 2. Topología Declarativa (`definitions.json`)

El broker local carga `definitions.json` al arrancar, de modo que la topologia existe antes de que arranque cualquier servicio.

### 2.1 Exchanges Declarados (3)
| Exchange | Tipo | Uso |
| :--- | :--- | :--- |
| `cmd.direct` | direct | Publicacion de comandos desde envios |
| `cmd.topic` | topic | Suscripcion por patrones |
| `cmd.dead.dlx` | direct | Dead Letter Exchange |

### 2.2 Colas, Colas de Espera y Dead Letter Queues (9 Colas)
| Cola | Tipo | Argumentos |
| :--- | :--- | :--- |
| `q.cmd.email`, `q.cmd.warehouse`, `q.cmd.label` | principal | DLX `cmd.dead.dlx`, DLK `<caso>.dead`, TTL 86400000 ms, largo maximo 10000 |
| `q.cmd.email.dlq`, `q.cmd.warehouse.dlq`, `q.cmd.label.dlq` | DLQ | TTL 604800000 ms, largo maximo 50000 |
| `q.cmd.email.retry`, `q.cmd.warehouse.retry`, `q.cmd.label.retry` | espera | DLX `cmd.direct`, DLK original (`email.send`, `warehouse.ticket`, `label.gen`), TTL 10000 ms (`esperaMs`), sin largo maximo |

### 2.3 Matriz de Enlaces (Bindings)
Son 15 enlaces. Por cada caso de uso (email, warehouse, label):

| Exchange | Cola destino | Clave |
| :--- | :--- | :--- |
| `cmd.direct` | cola principal | `email.send` / `warehouse.ticket` / `label.gen` |
| `cmd.topic` | cola principal | `email.*` / `warehouse.#` / `label.*` |
| `cmd.dead.dlx` | DLQ | `<caso>.dead` |
| `cmd.dead.dlx` | DLQ | clave original (`email.send`, `warehouse.ticket`, `label.gen`) |
| `cmd.dead.dlx` | DLQ | nombre de la propia DLQ |

Las colas de espera (`q.cmd.*.retry`) no poseen bindings ni consumidores; reciben mensajes exclusivamente por publicacion directa con clave igual a su nombre, y al vencer el TTL derivan de vuelta a `cmd.direct` con la clave original.

---

## 3. Guía de Ejecución Rápida

### Levantar el Broker
```bash
docker compose -f infra/mq/compose.yml up -d
```

### Ejecutar la Suite de Verificación Autónoma
```powershell
powershell -ExecutionPolicy Bypass -File infra/mq/verificar_mq.ps1
```

### Detener el Broker
```bash
docker compose -f infra/mq/compose.yml down
```

### Reinicio Limpio con Eliminación de Volúmenes
```bash
docker compose -f infra/mq/compose.yml down -v
```

---

## 4. Fuente de verdad y recreacion de colas (Issue #99 e Issue #106)

### 4.1 Fuente de verdad
La fuente autoritativa de la topologia son los beans de `ms-rutaexpress-notificaciones` (`TopologiaRabbitMQConfig`) y las propiedades `rutaexpress.mensajeria.*`. `definitions.json` y `infra/aws-ec2/scripts/bootstrap-mq.sh` preaprovisionan la misma topologia para que el broker tenga las colas antes del primer arranque de los servicios. `infra/aws-ec2/verificar_despliegue_aws.ps1` compara ambos archivos y reporta cualquier diferencia. `ms-rutaexpress-envios` declara solo el exchange `cmd.direct`, en el que publica.

### 4.2 Por que cambiar un argumento obliga a recrear la cola
`PRECONDITION_FAILED` es el error con el que RabbitMQ rechaza declarar un recurso que ya existe con atributos distintos (por ejemplo, una cola sin TTL cuando la nueva declaracion trae TTL). La declaracion solo es idempotente si es identica. Por eso, si cambia un argumento (TTL, largo maximo, DLX), la cola existente debe eliminarse y crearse de nuevo antes de desplegar la version del servicio que declara el valor nuevo.

Las colas de espera `q.cmd.*.retry` fijan su TTL mediante la propiedad `rutaexpress.mensajeria.reintentos.espera-ms`. Modificar este valor altera el atributo `x-message-ttl` y por tanto exige eliminar y recrear las tres colas de espera antes del despliegue del servicio para evitar `PRECONDITION_FAILED`. Como normalmente estas colas estan vacias o tienen muy pocos mensajes en transito, la recreacion es de bajo impacto.

### 4.3 Orden de despliegue obligatorio
1. Alinear el broker (`bootstrap-mq.sh` y `definitions.json`) y recrear las colas con el procedimiento A o B.
2. Desplegar `ms-rutaexpress-notificaciones`.
3. Desplegar `ms-rutaexpress-envios` (independiente del broker).

Si notificaciones llega antes de recrear las colas en AWS, la declaracion falla con `PRECONDITION_FAILED` y los consumidores no arrancan.

### 4.4 Procedimiento A: desplegar desde cero (laboratorio academico)
Lo ejecuta el usuario a mano; ningun script del repositorio lo invoca. Los mensajes pendientes se pierden.
- `terraform destroy` y luego `terraform apply`, o
- `terraform apply -replace=aws_instance.ec2_mq -replace=aws_instance.ec2_apps`.

Con `-replace` sobre `ec2_mq` la IP privada cambia. Como `ec2_apps` la recibe al crearse y su `user_data` no se vuelve a ejecutar, tambien debe reemplazarse `ec2_apps`.

### 4.5 Procedimiento B: en caliente, sin reemplazar instancias
1. Detener `ms-rutaexpress-notificaciones` en `ec2_apps`.
2. Verificar en la consola `15672` que las colas esten vacias, o aceptar la perdida de sus mensajes.
3. Por SSH a `ec2_mq`, reemplazar `/opt/rutaexpress/mq/definitions.json` por la version alineada. Este paso es obligatorio: si al reiniciar queda el JSON antiguo, la importacion vuelve a crear las colas sin TTL y el conflicto reaparece.
4. Eliminar las colas necesarias (consola o `rabbitmqadmin delete queue name=...`).
5. Ejecutar `docker compose restart` en `/opt/rutaexpress/mq`.
6. Levantar la nueva version de notificaciones.

En local no hace falta recrear nada: `definitions.json` ya contiene los argumentos objetivo.

### 4.6 Limites de la DLQ
Una DLQ llena (50000 mensajes) o con mensajes de mas de 7 dias (604800000 ms) descarta mensajes en silencio. Conviene revisar las DLQ antes de que alcancen esos limites.

### 4.7 Consideraciones operacionales de reintentos (Issue #106)
- **Riesgo B22 (Mensajes duplicados tras fallo de ACK del original):** La arquitectura garantiza entrega *at-least-once* (al menos una vez). Primero se confirma la publicacion de la copia en la cola de espera y luego se ejecuta el `basicAck` del mensaje original. Si ocurre una caida de red o del consumidor entre la confirmacion de la copia y el ACK del original, el mensaje original volvera a entregarse y coexistira con la copia. Este riesgo es aceptado; la deduplicacion idempotente basada en `eventoId` se aborda en el issue #92.
- **Riesgo B23 (Reordenamiento de mensajes):** Al fallar temporalmente el procesamiento, la copia del mensaje pasa por la cola de espera antes de ser reinyectada a la cola principal. Los mensajes subsiguientes que no fallen pueden procesarse antes del mensaje reintentado. El sistema acepta este comportamiento para operaciones que no requieren garantia estricta de orden FIFO.

---

## 5. Microservicio Administrador y Recursos Protegidos (Issue #97)

Para evitar colisiones entre la topologia del sistema y los recursos declarados dinamicamente por administradores mediante la API REST, se define una convencion estricta de prefijos protegidos implementada en `ms-rutaexpress-mensajeria`.

### 5.1 Convencion de Prefijos del Sistema
Toda topologia interna de los microservicios de negocio utiliza de forma obligatoria los siguientes prefijos:
- Colas del sistema: prefijo `q.cmd.` (por ejemplo `q.cmd.email`, `q.cmd.warehouse`, `q.cmd.label`, sus DLQ `q.cmd.*.dlq` y sus colas de espera `q.cmd.*.retry`).
- Exchanges del sistema: prefijo `cmd.` (por ejemplo `cmd.direct`, `cmd.topic`, `cmd.dead.dlx`).
- Recursos internos de RabbitMQ: prefijo `amq.` (exchanges predeterminados del broker).
- Exchange predeterminado: vacio (`""`).

### 5.2 Reglas de Proteccion en `ms-rutaexpress-mensajeria`
El microservicio administrador rechaza con codigo HTTP 409 (Conflicto):
1. Creacion de colas o exchanges que comiencen con `q.cmd.`, `cmd.` o `amq.`.
2. Eliminacion de colas o exchanges que comiencen con `q.cmd.`, `cmd.` o `amq.`.
3. Creacion o eliminacion de bindings cuyo exchange o cola destino pertenezca a la topologia protegida.
4. Asignacion de un exchange muerto (`x-dead-letter-exchange`) que sea un exchange protegido del sistema.

### 5.3 Canal de Administracion
La administracion se expone a traves de `ms-rutaexpress-bff` bajo la ruta `/api/bff/mensajeria/**`, restringida exclusivamente al rol `ROLE_ADMIN` y reenviada internamente a `ms-rutaexpress-mensajeria` con autenticacion interna `X-Servicio-Interno`.
