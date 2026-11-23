# Arquitectura de Despliegue Multi-Instancia en AWS (RutaExpress)

## Descripcion General
Este modulo (`infra/aws-ec2`) implementa la infraestructura como codigo (Terraform) y los scripts de aprovisionamiento automatizado (User Data) para trasladar la arquitectura desacoplada de RutaExpress desde el entorno local hacia maquinas virtuales Amazon EC2 segmentadas por rol y responsabilidad tecnica.

---

## Diagrama de Arquitectura y Flujo de Comunicacion

```
                           [ Internet / Clientes Web ]
                                        │
                                        ▼ (HTTPS :443)
┌─────────────────────────────────────────────────────────────────────────────┐
│                            VPC (10.10.0.0/16)                               │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Subred Publica (10.10.1.0/24)                      │  │
│  │                                                                       │  │
│  │   ┌───────────────────────────────────────────────────────────────┐   │  │
│  │   │                     Instancia ec2-apps                        │   │  │
│  │   │                    (IP Publica + Privada)                     │   │  │
│  │   │                                                               │   │  │
│  │   │  • Nginx Reverse Proxy (HTTPS :443 / Contexto Seguro MSAL)    │   │  │
│  │   │  • Backend For Frontend - ms-rutaexpress-bff (:8080)          │   │  │
│  │   │  • Frontend Web Angular - rutaexpress-frontend                │   │  │
│  │   │  • Microservicios de Dominio (Envios, Catalogo, etc.)         │   │  │
│  │   └──────────────────────┬──────────────────────┬─────────────────┘   │  │
│  └──────────────────────────┼──────────────────────┼─────────────────────┘  │
│                             │                      │                        │
│                             │ AMQP (:5672)         │ Kafka (:9092)          │
│                             │ (Solo sg_ec2_apps)   │ (Solo sg_ec2_apps)     │
│                             ▼                      ▼                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Subred Brokers (10.10.2.0/24)                      │  │
│  │                                                                       │  │
│  │   ┌─────────────────────────────┐   ┌─────────────────────────────┐   │  │
│  │   │      Instancia ec2-mq       │   │    Instancia ec2-kafka      │   │  │
│  │   │                             │   │                             │   │  │
│  │   │ • RabbitMQ 3.13 (:5672)     │   │ • Apache Kafka (:9092)      │   │  │
│  │   │ • Topologia de 6 Colas + DLQ│   │ • Zookeeper (:2181)         │   │  │
│  │   │ • Management UI (:15672)    │   │ • Kafka UI (:8085)          │   │  │
│  │   └─────────────────────────────┘   └─────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Matriz de Security Groups y Segmentacion Estricta

| Security Group | Puerto / Protocolo | Origen Autorizado | Proposito |
| :--- | :--- | :--- | :--- |
| **`sg_ec2_apps`** | `443/TCP` (HTTPS) | `0.0.0.0/0` (Internet) | Trafico seguro cifrado hacia Nginx Reverse Proxy y MSAL |
| | `8080/TCP` (HTTP) | `0.0.0.0/0` (Internet) | Integracion HTTP_PROXY del API Gateway hacia ms-rutaexpress-bff. Riesgo aceptado R-B (issue #120), ver 'Riesgos aceptados' |
| | `80/TCP` (HTTP) | `0.0.0.0/0` (Internet) | Redireccion permanente HTTP 301 a HTTPS |
| | `22/TCP` (SSH) | `var.allowed_admin_cidr` | Gestion y administracion tecnica remota |
| **`sg_ec2_mq`** | `5672/TCP` (AMQP) | **`sg_ec2_apps` (Exclusivo)** | Aislamiento estricto: solo el backend produce/consume colas |
| | `15672/TCP` (HTTP) | `var.allowed_admin_cidr` | Panel de monitoreo RabbitMQ Management UI |
| | `22/TCP` (SSH) | `var.allowed_admin_cidr` | Administracion remota |
| **`sg_ec2_kafka`** | `9092/TCP` (Kafka) | **`sg_ec2_apps` (Exclusivo)** | Aislamiento estricto: solo el backend produce/consume eventos |
| | `8085/TCP` (HTTP) | `var.allowed_admin_cidr` | Panel de inspeccion Kafka UI |
| | `22/TCP` (SSH) | `var.allowed_admin_cidr` | Administracion remota |

---

## Estructura del Modulo

- `main.tf`: Declaracion de la VPC, subredes, tablas de enrutamiento, reglas de aislamiento de Security Groups y las 3 instancias EC2 (`ec2_apps`, `ec2_mq`, `ec2_kafka`).
- `variables.tf`: Parametrizacion de region AWS, tipos de instancia (`t3.medium`, `t3.small`), rangos CIDR y claves SSH.
- `outputs.tf`: Exportacion automatica de IPs publicas y privadas, comandos SSH formateados y URLs directas a los paneles.
- `scripts/bootstrap-mq.sh`: Script de inicializacion para `ec2-mq` que instala Docker, aprovisiona RabbitMQ 3.13 y declara la topologia de 6 colas, 3 exchanges y Dead Letter Queues.
- `scripts/bootstrap-kafka.sh`: Script para `ec2-kafka` que aprovisiona Zookeeper, Kafka y Kafka UI, configurando `KAFKA_ADVERTISED_LISTENERS` con la IP privada para enrutamiento interno.
- `scripts/bootstrap-apps.sh`: Script para `ec2-apps` que inyecta las IPs privadas de `ec2-mq` y `ec2-kafka` en el archivo `.env`, genera certificados SSL y levanta la suite de microservicios tras Nginx HTTPS.
- `verificar_despliegue_aws.ps1`: Suite automatizada de comprobacion de reglas de aislamiento de red y sintaxis HCL.

---

## Procedimiento de Despliegue en AWS

1. **Configurar Credenciales de AWS**:
   ```powershell
   $env:AWS_ACCESS_KEY_ID="tu-access-key"
   $env:AWS_SECRET_ACCESS_KEY="tu-secret-key"
   $env:AWS_SESSION_TOKEN="tu-session-token" # Si se utiliza AWS Academy / Learner Lab
   ```

2. **Validar la Configuracion de Infraestructura**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/aws-ec2/verificar_despliegue_aws.ps1
   ```

3. **Ejecutar Despliegue con Terraform**:
   ```bash
   cd infra/aws-ec2
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

   > Nota (issue #99): `user_data` solo se ejecuta en el primer arranque de la instancia. Modificar `bootstrap-mq.sh` no reconfigura un `ec2_mq` existente. Para aplicar una topologia nueva de RabbitMQ, ver `infra/mq/README.md`, seccion 4.

4. **Comprobar Conectividad Cloud**:
   - Abrir en el navegador: `https://<ec2_apps_public_ip>/salud-proxy`
   - Monitorear RabbitMQ: `http://<ec2_mq_public_ip>:15672/`
   - Monitorear Kafka: `http://<ec2_kafka_public_ip>:8085/`

5. **Inyectar el Oracle Wallet**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/aws-ec2/inyectar_wallet.ps1 -KeyPath <ruta-a-labsuser.pem>
   ```
   El script copia el wallet a `ec2-apps`, recrea envios, catalogo, auditoria y BFF, y verifica que los cuatro contenedores queden en ejecucion con su nombre normal. Termina con codigo 0 si todo queda bien y con un codigo distinto de 0 (y un mensaje en rojo) si falla `scp`, `ssh` o algun contenedor no queda en ejecucion.

---

## API Gateway y JWT Authorizer (issue #101)

El API Gateway (HTTP API) valida el token de Microsoft Entra ID antes de reenviar la peticion al BFF.

- **Rutas protegidas por defecto:** `GET|POST|PUT|PATCH|DELETE /{proxy+}` exigen token (autorizador JWT). Una ruta nueva del BFF nace protegida: si no se declara como publica, responde 401 (denegacion por defecto).
- **Rutas publicas:** `GET|POST /api/publico/{proxy+}` no tienen autorizador y usan una segunda integracion (`/api/publico/{proxy}`), porque en esa ruta `{proxy}` captura solo lo que sigue al prefijo.
- **Emisor y audiencia:** tokens v1.0, emisor `https://sts.windows.net/<tenant>/` (con barra final, tenant en minusculas) y audiencia `api://a55c035c-76ef-4ddf-ab9a-545d90386f03`. Se parametrizan con `azure_ad_tenant_id` (obligatoria, sin valor por defecto) y `api_audiencias_jwt`. Deben coincidir exactamente con los que configure el BFF (issue #95).
- **Autenticacion y autorizacion:** el Gateway valida firma, emisor, audiencia y vigencia (401 si falla). Los roles los valida el BFF (403 si el rol no alcanza). El Gateway reenvia `Authorization` y el BFF vuelve a validar el token.
- **Preflight `OPTIONS`:** la responde el CORS nativo del Gateway sin token (204). Esta prohibido agregar rutas `OPTIONS`, `ANY` o `$default`, porque exigirian token a la preflight y el navegador bloquearia todas las llamadas.
- **CORS con cabeceras explicitas:** `allow_headers = ["authorization", "content-type"]`. Segun el estandar Fetch, el comodin no cubre `Authorization`, por lo que debe nombrarse. Si el frontend agrega una cabecera propia nueva, hay que agregarla en `api_gateway.tf`.
- **Registro de acceso:** el stage escribe en el grupo de CloudWatch `/aws/apigateway/<project_name>-api-gateway` (retencion de 14 dias) el estado, `integrationStatus` y el error del autorizador. No registra cabeceras ni tokens. Un rechazo del Gateway muestra `integrationStatus = "-"`. Si `terraform apply` falla por permisos de CloudWatch en AWS Academy, retirar `access_log_settings` y el grupo de registros, y distinguir el origen del 401 por el cuerpo: el Gateway responde `{"message":"Unauthorized"}` y el BFF responde cuerpo vacio con `WWW-Authenticate: Bearer`.

### Throttling y Retry-After (issue #120)

El stage `$default` implementa throttling global configurable (`gateway_throttling_rafaga = 100`, `gateway_throttling_tasa = 50`), protegiendo la capacidad general de la EC2 ante rafagas compartidas por todos los clientes. La ruta publica `GET /api/publico/{proxy+}` aplica un limite mas estricto (`gateway_throttling_publico_rafaga = 20`, `gateway_throttling_publico_tasa = 10`) para mitigar abusos sobre el cotizador y rutas sin autorizador. Si el throttling del Gateway se activa, responde HTTP 429 con cuerpo `{"message":"Too Many Requests"}`, a diferencia del 429 emitido por el limitador por IP del BFF que responde `{"codigo":"LIMITE_TASA_EXCEDIDO",...}` con cabecera `Retry-After`. Ademas, `expose_headers = ["retry-after"]` en CORS permite a los navegadores leer dicha cabecera ante respuestas 429 en llamadas de origen cruzado.

### Limitaciones declaradas

- **Acceso directo al BFF:** el BFF tambien es alcanzable por `http://<ip>:8080` y `https://<ip>/api/` sin pasar por el Gateway. Desde el issue #95 el BFF valida firma, vigencia, emisor y audiencia (las mismas variables de Terraform que el Gateway) tambien en el acceso directo; lo que permanece es la exposicion de red. Ver subseccion 'Riesgos aceptados' (R-B).
- **Token sin renovacion en el frontend:** `catalogo`, `auditoria` y `reportes` adjuntan el token guardado en `sessionStorage['access_token']`, obtenido una sola vez al volver del login. Tras su expiracion (60 a 90 minutos) reciben 401, ahora emitido por el Gateway. Es una limitacion preexistente que requiere un issue aparte en el frontend.
- **Orden de despliegue del BFF (issue #95):** `bootstrap-apps.sh` solo corre en el primer arranque de `ec2-apps` y `actualizar.sh` no regenera el `.env`. Antes de actualizar el BFF, agregar `AZURE_TENANT_ID` (GUID del tenant) y `AZURE_API_AUDIENCIAS` (las mismas audiencias de `api_audiencias_jwt`, separadas por comas) al `.env` existente, o recrear la instancia con `terraform apply -replace=aws_instance.ec2_apps`. Si se actualiza el BFF antes, no arranca (fallo cerrado esperado) y el servicio queda caido. El BFF ya no usa `JWK_SET_URI`.
- **Desfase de reloj:** cerca de `exp`, el Gateway puede rechazar un token que el BFF aun aceptaria (tolerancia de 60 s en Spring).

### Riesgos aceptados

- **R-B (Acceso directo al BFF y cifrado del tramo Gateway-EC2):** Quien conozca la IP publica puede invocar al BFF directamente a traves de dos puertas: `http://<ip>:8080` (HTTP plano) y `https://<ip>/api/` (Nginx TLS).
  - *Elementos de contencion:* ms-rutaexpress-bff valida de manera autonoma firma, emisor, audiencia y vigencia del JWT (#95). Por la puerta de Nginx, el proxy inyecta `$remote_addr` al final de `X-Forwarded-For` de forma confiable (`forward-headers-strategy: native`), garantizando que el limite de tasa por IP del cotizador opere por visitante real y no pueda falsearse.
  - *Elementos no contenidos:* El token viaja sin cifrar entre el API Gateway y el puerto 8080 de la EC2 a traves de la red publica de AWS, y el throttling del Gateway no protege las invocaciones directas a la EC2.
  - *Solucion para produccion:* Implementar VPC Link hacia un Network Load Balancer (NLB) interno en subred privada, cerrando la regla del puerto 8080 en el Security Group unicamente al rango CIDR de la VPC.

### Guia de demostracion con curl (PowerShell)

No usar `--insecure` contra el Gateway: tiene certificado valido de AWS. El token nunca se pega en la consola ni en archivos.

```powershell
$gw = terraform -chdir=infra/aws-ec2 output -raw api_gateway_url

# 1. Sin token: 401 del Gateway, cuerpo {"message":"Unauthorized"}
curl.exe -s -i "$gw/api/bff/envios"

# 2. Token alterado: 401 del Gateway
#    Copiar el token desde el navegador (DevTools > Application > Session Storage > access_token)
#    al portapapeles.
$env:RUTAEXPRESS_TOKEN = (Get-Clipboard)
$alterado = $env:RUTAEXPRESS_TOKEN.Substring(0, $env:RUTAEXPRESS_TOKEN.Length - 1) + 'A'
curl.exe -s -i -H "Authorization: Bearer $alterado" "$gw/api/bff/envios"

# 3. Token valido: 200 desde el BFF (solo se muestra el codigo)
curl.exe -s -o NUL -w "%{http_code}`n" -H "Authorization: Bearer $env:RUTAEXPRESS_TOKEN" "$gw/api/bff/envios"

# 4. Rutas publicas sin token: 200
curl.exe -s -o NUL -w "%{http_code}`n" "$gw/api/publico/salud"

# 5. Preflight sin token: 204
curl.exe -s -o NUL -w "%{http_code}`n" -X OPTIONS -H "Origin: https://<ec2_apps_public_ip>" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: authorization" "$gw/api/bff/envios"

# Evidencia de que el 401 no llego al BFF (integrationStatus "-")
$logGroup = (terraform -chdir=infra/aws-ec2 output -json jwt_authorizer | ConvertFrom-Json).log_group
aws logs tail $logGroup --since 10m

Remove-Item Env:RUTAEXPRESS_TOKEN
```

Pasos manuales adicionales (los claims se revisan con `colaboracion/herramientas/extraer_claims_jwt.ps1`, sin mostrar nunca el token completo):

- **B3, token vencido:** usar un token guardado de mas de una hora (en variable de entorno); esperado 401 del Gateway.
- **B4, otro tenant:** token de una cuenta de otro tenant (`iss` distinto); esperado 401 del Gateway. Requiere una cuenta de otro tenant; si no existe, queda no verificado.
- **B5, otra audiencia:** token de Microsoft Graph (`aud = 00000003-...`); esperado 401 del Gateway.
- **B6, sin prefijo `Bearer`:** el Gateway acepta el token sin el prefijo, pero el BFF no reconoce el esquema y responde 401 (`integrationStatus` numerico en el registro).

---

## Recuperacion tras una inyeccion interrumpida

Si una recreacion de contenedores se corta a mitad (por ejemplo, porque se perdio la sesion SSH), los servicios pueden quedar detenidos o con nombres temporales del tipo `<id>_ms-rutaexpress-envios`.

1. Diagnosticar desde `ec2-apps`:
   ```bash
   sudo docker ps -a --format '{{.Names}} {{.Status}}'
   ```
2. Recrear los cuatro servicios con las imagenes ya construidas (sin compilar de nuevo):
   ```bash
   cd /opt/rutaexpress/RUTAEXPRESS_VGUARDIA_CMORALES
   sudo docker compose -f infra/apps/compose.yml up -d --no-build --force-recreate ms-rutaexpress-envios ms-rutaexpress-catalogo ms-rutaexpress-auditoria ms-rutaexpress-bff
   ```
3. Repetir el paso 1 y confirmar que los cuatro aparecen como `Up` con su nombre normal.
