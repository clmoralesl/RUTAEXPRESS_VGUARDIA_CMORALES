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
