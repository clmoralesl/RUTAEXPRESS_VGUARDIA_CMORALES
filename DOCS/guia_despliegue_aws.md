# Guía de Despliegue de Infraestructura AWS (EKS + ECR) con Terraform (AWS Learner Lab)

Esta guía detalla los pasos exactos para aprovisionar, conectar y destruir la infraestructura requerida para el proyecto RutaExpress utilizando Terraform y AWS CLI en un entorno de **AWS Academy / Learner Lab**.

> [!IMPORTANT]
> **Compatibilidad con AWS Learner Lab:**
> Las cuentas de Learner Lab prohíben la creación de nuevos Roles IAM (`iam:CreateRole`). Por ello, Terraform ha sido configurado para reutilizar automáticamente el rol predeterminado **`LabRole`** otorgado por AWS Academy.

---

## Prerrequisitos

Asegúrate de tener instaladas las siguientes herramientas en tu sistema local:
1. **AWS CLI:** Herramienta de línea de comandos de AWS.
2. **Terraform:** (Versión >= 1.3.0).
3. **kubectl:** Cliente de línea de comandos para Kubernetes.
4. **Git:** Para clonar y manejar versiones.

---

## Paso 1: Configurar Credenciales de AWS Learner Lab

En AWS Learner Lab, las credenciales cambian cada vez que inicias o reinicias la sesión en la plataforma y requieren un **AWS Session Token**.

1. Inicia la consola de tu **AWS Learner Lab**.
2. Haz clic en el botón **"AWS Details"** (junto al botón verde de "Start Lab").
3. En la sección **AWS CLI**, copia el bloque de texto con tus credenciales temporales. Se verá similar a esto:
   ```env
   aws_access_key_id=ASIA...
   aws_secret_access_key=...
   aws_session_token=IQoJb3JpZ2luX2Vj...
   ```
4. En tu máquina local, abre el archivo de credenciales de AWS (o ejecútalo mediante variables de entorno):
   * **En Linux/macOS o Git Bash / PowerShell:**
     Puedes pegarlo directamente en tu archivo `~/.aws/credentials` o en PowerShell:
     ```powershell
     $env:AWS_ACCESS_KEY_ID="ASIA..."
     $env:AWS_SECRET_ACCESS_KEY="..."
     $env:AWS_SESSION_TOKEN="IQoJ..."
     $env:AWS_DEFAULT_REGION="us-east-1"
     ```
   * **O usando `aws configure`:**
     Ejecuta `aws configure` e ingresa el Key y Secret Key. Luego debes agregar manualmente el `aws_session_token` en `~/.aws/credentials` bajo el perfil por defecto (`[default]`).

---

## Paso 2: Despliegue con Terraform

Navega a la carpeta donde se encuentra la configuración de Terraform:
```bash
cd infra/terraform
```

### Inicializar Terraform
Descarga los proveedores (AWS, Kubernetes) y módulos requeridos:
```bash
terraform init
```

### Planificar el Despliegue
Verifica qué recursos se van a crear (no hará cambios reales en AWS aún):
```bash
terraform plan
```
*Comprueba que en el plan se utilice el ARN de `LabRole` para el clúster de EKS.*

### Aplicar el Despliegue
Ejecuta los cambios para crear la infraestructura en AWS. EKS tardará entre 10 y 15 minutos en desplegarse completamente.
```bash
terraform apply
```
*Escribe `yes` cuando te pregunte si deseas realizar estas acciones.*

---

## Paso 3: Conectar a EKS localmente

Al finalizar, Terraform mostrará varios **Outputs**. Uno de ellos te dará el comando exacto para configurar tu conexión a EKS.

1. Ejecuta el comando sugerido por el output de Terraform:
   ```bash
   aws eks --region us-east-1 update-kubeconfig --name rutaexpress-cluster
   ```
2. Verifica la conexión comprobando que los nodos están en estado "Ready":
   ```bash
   kubectl get nodes
   ```

---

## Paso 4: Login y Push hacia ECR

Para que tu orquestador y Git Actions puedan subir contenedores, necesitas hacer login a ECR.

1. En PowerShell de Windows, el comando de tubería (`|`) agrega saltos de línea (`\r\n`) al token. Ejecuta el login asignando la contraseña directamente:
   ```powershell
   docker login --username AWS --password (aws ecr get-login-password --region us-east-1) 526905849168.dkr.ecr.us-east-1.amazonaws.com
   ```
   *(O alternativamente: `$token = (aws ecr get-login-password --region us-east-1).Trim()` y luego `docker login --username AWS --password $token ...`)*
2. Esto te permitirá tagear imágenes locales y subirlas (`docker push`) a los repositorios creados (`rutaexpress-bff`, `rutaexpress-envios`, `rutaexpress-frontend`).

---

## Paso 5: Limpieza y Apagado (Destrucción de Infraestructura)

Para evitar agotar el presupuesto o tiempo límite de tu Learner Lab, destruye la infraestructura al terminar tus pruebas.

### ⚠️ ¡Paso CRÍTICO para evitar errores de VPC y Subredes!
Dado que Kubernetes (EKS) crea los Load Balancers de AWS automáticamente cuando aplicas tus manifiestos (ej. el BFF), Terraform no los conoce. Si destruyes Terraform primero, esos Load Balancers quedarán huérfanos bloqueando el borrado de la red. **Siempre debes borrar los recursos de Kubernetes primero:**

1. Asegúrate de estar conectado al clúster:
   ```bash
   aws eks --region us-east-1 update-kubeconfig --name rutaexpress-cluster
   ```
2. Borra los servicios expuestos para que EKS elimine los Load Balancers:
   ```bash
   kubectl delete svc ms-rutaexpress-bff
   # O simplemente borra todo lo que desplegaste:
   # kubectl delete -f infra/k8s/
   ```
3. Espera un par de minutos a que AWS elimine físicamente los balanceadores.

### Destruir la infraestructura con Terraform
4. Navega al directorio de Terraform:
   ```bash
   cd infra/terraform
   ```
5. Ejecuta la destrucción:
   ```bash
   terraform destroy -auto-approve
   ```
*Gracias a la bandera `force_delete = true` en ECR, Terraform eliminará la VPC, EKS y los repositorios ECR de forma limpia y automática.*
