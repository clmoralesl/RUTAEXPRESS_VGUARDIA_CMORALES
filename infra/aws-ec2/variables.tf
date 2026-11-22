# ==============================================================================
# Variables de Configuracion - Despliegue Multi-Instancia AWS (Issue #26)
# ==============================================================================

variable "aws_region" {
  description = "Region de AWS para el despliegue distribuido"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombramiento de recursos"
  type        = string
  default     = "rutaexpress"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "sprint2"
}

variable "vpc_cidr" {
  description = "Rango CIDR para la VPC dedicada de RutaExpress"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subred publica para ec2-apps"
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR de la subred para brokers ec2-mq y ec2-kafka"
  type        = string
  default     = "10.10.2.0/24"
}

variable "instance_type_apps" {
  description = "Tipo de instancia EC2 para frontend, BFF y microservicios"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_mq" {
  description = "Tipo de instancia EC2 para el cluster RabbitMQ"
  type        = string
  default     = "t3.small"
}

variable "instance_type_kafka" {
  description = "Tipo de instancia EC2 para Zookeeper, Kafka y Kafka UI"
  type        = string
  default     = "t3.medium"
}

variable "ssh_key_name" {
  description = "Nombre del Key Pair de AWS para administracion por SSH"
  type        = string
  default     = "rutaexpress-key"
}

variable "allowed_admin_cidr" {
  description = "CIDR autorizado para acceso SSH y consolas de administracion"
  type        = string
  default     = "0.0.0.0/0"
}

# ==============================================================================
# Credenciales de Oracle ATP (Issue #94)
# Sin valor por defecto: se entregan en terraform.tfvars (excluido de Git) o con
# variables de entorno TF_VAR_<nombre>. Ver terraform.tfvars.example.
# El conjunto de caracteres es restringido porque bootstrap-apps.sh escribe el
# .env con un heredoc sin comillas: bash alteraria $, acento grave, \ o comillas.
# Los espacios se excluyen porque un # precedido de espacio inicia un comentario
# en el .env que lee Docker Compose.
# ==============================================================================

variable "oracle_envios_password" {
  description = "Contrasena de USER_ENVIOS en Oracle ATP (tambien usada por ORACLE_DB_PASSWORD)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_.#-]{12,30}$", var.oracle_envios_password))
    error_message = "oracle_envios_password debe tener entre 12 y 30 caracteres y usar solo letras, digitos, guion bajo, guion, punto o numeral."
  }
}

variable "oracle_catalogo_password" {
  description = "Contrasena de USER_CATALOGO en Oracle ATP"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_.#-]{12,30}$", var.oracle_catalogo_password))
    error_message = "oracle_catalogo_password debe tener entre 12 y 30 caracteres y usar solo letras, digitos, guion bajo, guion, punto o numeral."
  }
}

variable "oracle_auditoria_password" {
  description = "Contrasena de USER_AUDITORIA en Oracle ATP"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_.#-]{12,30}$", var.oracle_auditoria_password))
    error_message = "oracle_auditoria_password debe tener entre 12 y 30 caracteres y usar solo letras, digitos, guion bajo, guion, punto o numeral."
  }
}

# ==============================================================================
# JWT Authorizer del API Gateway con Microsoft Entra ID (Issue #101)
# El emisor y la audiencia deben coincidir con los que valida el BFF (issue #95).
# Tokens de la API en formato v1.0: iss = https://sts.windows.net/<tenant>/
# ==============================================================================

variable "azure_ad_tenant_id" {
  description = "ID del tenant de Microsoft Entra ID que emite los tokens (GUID). Sin valor por defecto: se entrega en terraform.tfvars o TF_VAR_azure_ad_tenant_id"
  type        = string

  validation {
    condition     = can(regex("^(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.azure_ad_tenant_id))
    error_message = "azure_ad_tenant_id debe ser un GUID (formato xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."
  }
}

variable "api_audiencias_jwt" {
  description = "Audiencias (claim aud) aceptadas por el JWT Authorizer. Tokens v1.0 de la API de RutaExpress usan el App ID URI"
  type        = list(string)
  default     = ["api://a55c035c-76ef-4ddf-ab9a-545d90386f03"]

  validation {
    condition     = length(var.api_audiencias_jwt) > 0 && alltrue([for a in var.api_audiencias_jwt : can(regex("^[A-Za-z0-9:/._-]+$", a))])
    error_message = "api_audiencias_jwt debe contener al menos una audiencia, solo con letras, digitos y los caracteres : / . _ - (el valor se escribe en un .env sin comillas y separado por comas)."
  }
}
