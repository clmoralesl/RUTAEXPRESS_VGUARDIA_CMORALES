# Guia de Redespliegue: Infraestructura AWS EC2, Oracle Cloud y Azure AD

Esta guia detalla el procedimiento operativo para volver a aprovisionar, configurar y validar el ecosistema completo de microservicios y frontend de **RutaExpress** en un entorno de **AWS Academy Learner Lab** utilizando Terraform, Docker Compose, Oracle Autonomous Database (ATP) y Microsoft Entra ID (Azure AD).

---

## 1. Archivos Requeridos y Ubicacion Obligatoria

Antes de iniciar el redespliegue, verificar que se encuentren disponibles los siguientes dos archivos confidenciales en la raiz del repositorio clonado:

| Archivo | Descripcion | Ubicacion Relativa Obligatoria |
| :--- | :--- | :--- |
| **`labsuser.pem`** | Llave privada SSH otorgada por AWS Academy para acceso administrativo a instancias EC2. *(Valida para todo el semestre, no cambia al reiniciar el lab).* | `infra/labsuser.pem` |
| **`Wallet_rutaexpressdb.zip`** | Certificados y billetera de conexion mTLS hacia la base de datos Oracle Autonomous Database en la nube. | `infra/oracle/Wallet_rutaexpressdb.zip` |

> [!NOTE]
> Ambos archivos se encuentran estrictamente protegidos mediante `.gitignore` para prevenir cualquier exposicion en el historial de Git.

---

## 2. Paso a Paso de Ejecucion

### Paso 1: Clonar el Repositorio y Ubicar Archivos
Abrir una terminal de PowerShell:
```powershell
# Clonar el proyecto principal
git clone https://github.com/clmoralesl/RUTAEXPRESS_VGUARDIA_CMORALES.git
cd RUTAEXPRESS_VGUARDIA_CMORALES

# Copiar los archivos a sus respectivas ubicaciones
Copy-Item "C:\Ruta\Hacia\labsuser.pem" "infra\labsuser.pem"
Copy-Item "C:\Ruta\Hacia\Wallet_rutaexpressdb.zip" "infra\oracle\Wallet_rutaexpressdb.zip"
```

### Paso 2: Cargar Credenciales de AWS Academy
En la consola web de AWS Academy:
1. Iniciar el laboratorio pulsando **Start Lab** (esperar que el circulo pase a verde).
2. Hacer clic en **AWS Details** > **AWS CLI**.
3. Copiar las variables temporales y ejecutarlas en su terminal de PowerShell:
```powershell
$env:AWS_ACCESS_KEY_ID="ASI..."
$env:AWS_SECRET_ACCESS_KEY="..."
$env:AWS_SESSION_TOKEN="..."
$env:AWS_DEFAULT_REGION="us-east-1"
```

### Paso 3: Aprovisionar Infraestructura con Terraform
Navegar al directorio de Terraform para EC2 y aplicar los cambios:
```powershell
cd infra\aws-ec2

# Inicializar proveedores y modulos
terraform init

# Desplegar las 3 instancias EC2, VPC, Subnets y AWS API Gateway
terraform apply -auto-approve
```

Al terminar el despliegue (aproximadamente 2 minutos), Terraform mostrara en pantalla las salidas de infraestructura:
* `ec2_apps_public_ip`: Direccion IP publica de la instancia principal (Frontend, BFF, Microservicios).
* `ec2_mq_public_ip`: Direccion IP publica de RabbitMQ.
* `ec2_kafka_public_ip`: Direccion IP publica de Kafka.
* `api_gateway_endpoint`: URL base del AWS API Gateway HTTP API v2.

### Paso 4: Registrar la Nueva IP en Azure Portal
1. Ingresar a [Azure Portal](https://portal.azure.com/).
2. Dirigirse a **Microsoft Entra ID** > **Registros de aplicaciones**.
3. Seleccionar la aplicacion con Client ID `853e11cd-e801-4317-96e7-bda1c6dd8d74`.
4. En el menu lateral izquierdo, hacer clic en **Autenticacion**.
5. En la seccion **Aplicacion de una sola pagina (SPA)**, hacer clic en **Agregar URI**.
6. Añadir la siguiente URL (reemplazando con la IP obtenida en el Paso 3):
   ```text
   https://<ec2_apps_public_ip>/
   ```
7. Hacer clic en **Guardar**.
*(No es necesario eliminar las IPs de sesiones anteriores; Azure permite acumularlas).*

### Paso 5: Inyectar la Billetera de Oracle Cloud
Desde la misma terminal en `infra\aws-ec2`, ejecutar:
```powershell
.\inyectar_wallet.ps1
```
El script realiza de manera desatendida:
1. Lectura de la IP publica de `ec2-apps` directamente desde Terraform.
2. Transferencia segura via SCP de `Wallet_rutaexpressdb.zip` utilizando `infra/labsuser.pem`.
3. Descompresion en el servidor aplicando permisos `755` para el directorio y `644` para los certificados.
4. Reinicio automatico de los microservicios dependientes de Oracle (`ms-rutaexpress-envios`, `ms-rutaexpress-catalogo`, `ms-rutaexpress-auditoria`, `ms-rutaexpress-bff`) para conectar los pools de HikariCP inmediatamente.

---

## 3. Verificacion y Accesos

| Servicio | URL / Metodo de Acceso | Descripcion |
| :--- | :--- | :--- |
| **Frontend Web** | `https://<ec2_apps_public_ip>/` | Aplicacion Angular 20. Aceptar la advertencia de certificado autofirmado en el navegador. |
| **Healthcheck BFF** | `https://<ec2_apps_public_ip>/api/publico/salud` | Retorna estado del BFF tras pasar por el reverse proxy Nginx con HTTPS. |
| **AWS API Gateway** | `<api_gateway_endpoint>/api/publico/salud` | Endpoint perimetral nativo en AWS con CORS gestionado en la nube. |
| **RabbitMQ Management** | `http://<ec2_mq_public_ip>:15672/` | Panel administrativo de RabbitMQ. Credenciales: `guest` / `guest`. |
| **Kafka UI** | `http://<ec2_kafka_public_ip>:8085/` | Inspeccion visual de topicos (`shipments.events`) y consumidores de Kafka. |

---

## 4. Apagado y Destruccion de Recursos

Al finalizar la jornada de trabajo, para evitar agotar las horas y los creditos de su cuenta de AWS Academy:
```powershell
cd infra\aws-ec2
terraform destroy -auto-approve
```
Verificar que la salida final indique:
```text
Destroy complete! Resources: 17 destroyed.
```

---

## 5. Prompt de Ejecucion Desatendida para Agentes de Inteligencia Artificial

Si se requiere que un asistente o agente de IA ejecute el proceso de forma autonoma, copiar y enviar el siguiente prompt:

```text
Actua como ingeniero DevOps y redespliega el entorno completo de RutaExpress en AWS EC2 mediante Terraform.
Instrucciones estrictas a ejecutar en orden:
1. Comprueba la existencia de los archivos locales 'infra/labsuser.pem' e 'infra/oracle/Wallet_rutaexpressdb.zip'.
2. Verifica que las credenciales de sesion de AWS ($env:AWS_ACCESS_KEY_ID, $env:AWS_SECRET_ACCESS_KEY, $env:AWS_SESSION_TOKEN) esten presentes con region 'us-east-1'.
3. Ubicate en 'infra/aws-ec2', ejecuta 'terraform init' y 'terraform apply -auto-approve'.
4. Extrae de las salidas de Terraform las variables 'ec2_apps_public_ip', 'ec2_mq_public_ip', 'ec2_kafka_public_ip' y 'api_gateway_endpoint'.
5. Solicita al usuario registrar 'https://<ec2_apps_public_ip>/' en Azure Portal (Microsoft Entra ID > Registros de aplicaciones > Client ID 853e11cd-e801-4317-96e7-bda1c6dd8d74 > Autenticacion > SPA URIs) y espera confirmacion.
6. Ejecuta '.\inyectar_wallet.ps1' para transferir la billetera de Oracle ATP y reiniciar los contenedores dependientes.
7. Comprueba la salud del sistema consumiendo 'https://<ec2_apps_public_ip>/api/publico/salud' y confirma que los 8 contenedores de ec2-apps, el panel de RabbitMQ (puerto 15672) y Kafka UI (puerto 8085) se encuentren operativos.
```

---

## 6. Resolucion de Problemas Frecuentes

* **Advertencia de Certificado SSL Autofirmado en el Navegador**:
  * Al ingresar a `https://<ec2_apps_public_ip>/`, hacer clic en **Configuracion avanzada** > **Continuar a <IP> (no seguro)**. Es el comportamiento esperado para entornos de laboratorio con terminacion TLS en Nginx.
* **Error de Autenticacion en Azure (`AADSTS50011: The redirect URI does not match`)**:
  * Ocurre si no se agrego la nueva IP publica generada por Terraform en las URIs de redireccion de Azure Portal. Repetir el Paso 4 asegurandose de incluir la barra inclinada final (`/`).
* **Verificacion del Estado de Contenedores via SSH**:
  ```powershell
  ssh -i infra/labsuser.pem ubuntu@<ec2_apps_public_ip> "sudo docker ps"
  ```
  Los 8 contenedores (`rutaexpress-frontend`, `ms-rutaexpress-bff`, `ms-rutaexpress-envios`, `ms-rutaexpress-catalogo`, `ms-rutaexpress-notificaciones`, `ms-rutaexpress-auditoria`, `ms-rutaexpress-reportes` y `rutaexpress-nginx-proxy`) deben encontrarse en estado `Up`.

---

## 7. Actualizacion de Repositorios y Despliegue en Caliente en EC2

Cuando se realicen nuevos commits o merges en la rama `main` de GitHub (en el frontend, BFF o cualquiera de los microservicios), no es necesario destruir la infraestructura para aplicar los cambios. Se puede sincronizar la instancia `ec2-apps` utilizando cualquiera de los siguientes dos metodos:

### Opcion A: Comando Directo por SSH (Recomendada y Rapida)
Desde su terminal local de PowerShell, ejecute:
```powershell
ssh -i infra/labsuser.pem ubuntu@<ec2_apps_public_ip> "sudo /opt/rutaexpress/actualizar.sh"
```
**Acciones que ejecuta el script en el servidor:**
1. Realiza `git fetch origin main` y `git reset --hard origin/main` en los 8 repositorios ubicados en `/opt/rutaexpress/`.
2. Ejecuta `docker compose -f infra/apps/compose.yml up -d --build`, recompilando y recreando unicamente los contenedores que contengan modificaciones de codigo.
3. Mantiene intactas las conexiones activas a Oracle Cloud ATP, RabbitMQ y Apache Kafka sin interrupcion de servicio.

### Opcion B: Mediante GitHub Actions (Desde la Web de GitHub)
Si prefiere disparar la actualizacion desde la interfaz web de GitHub:
1. Ingrese al repositorio `RUTAEXPRESS_VGUARDIA_CMORALES` en GitHub y haga clic en la pestaña **Actions**.
2. En la lista lateral izquierda, seleccione el workflow **Actualizacion Manual de Despliegue en AWS EC2**.
3. Haga clic en el boton desplegable **Run workflow**.
4. Ingrese la direccion IP publica actual de `ec2-apps` en el campo `ec2_host` y confirme la ejecucion.
*(Requisito: Debe estar configurado el secreto `EC2_SSH_KEY` en `Settings > Secrets and variables > Actions` con el contenido del archivo `labsuser.pem`).*

