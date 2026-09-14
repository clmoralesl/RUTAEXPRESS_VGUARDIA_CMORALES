variable "aws_region" {
  description = "Región de AWS para desplegar la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster de EKS"
  type        = string
  default     = "rutaexpress-cluster"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ==============================================================================
# ROLES IAM DE AWS LEARNER LAB
# NOTA: Los nombres de los roles con prefijos/sufijos alfanuméricos son generados
# dinámicamente por AWS Academy. Si inicias un nuevo curso o reinicias el laboratorio,
# verifica en la consola IAM el nombre actual de tus roles y actualízalos aquí.
# ==============================================================================

variable "eks_cluster_role_name" {
  description = "Nombre del rol de IAM para el clúster de EKS en Learner Lab"
  type        = string
  default     = "c224313a5663957l16144452t1w526905-LabEksClusterRole-VZ6Jfgo6Y8f2"
}

variable "eks_node_role_name" {
  description = "Nombre del rol de IAM para los nodos de EC2 en Learner Lab"
  type        = string
  default     = "c224313a5663957l16144452t1w526905849-LabEksNodeRole-55SJscuAIZVu"
}

# ==============================================================================
# VARIABLES API GATEWAY & AZURE AD
# ==============================================================================

variable "azure_ad_tenant_id" {
  description = "Tenant ID de Azure AD para el JWT Authorizer"
  type        = string
  sensitive   = true
}

variable "azure_ad_client_id" {
  description = "Client ID de Azure AD para el JWT Authorizer"
  type        = string
  sensitive   = true
}

variable "bff_lb_url" {
  description = "URL (DNS) del Network Load Balancer del BFF expuesto por EKS"
  type        = string
}
