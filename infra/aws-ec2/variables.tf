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
