output "cluster_endpoint" {
  description = "Endpoint para el control plane de EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID adjunto al VPC config del cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Nombre de cluster de EKS"
  value       = aws_eks_cluster.main.name
}

output "ecr_repository_bff_url" {
  description = "URL del repositorio ECR para el BFF"
  value       = aws_ecr_repository.bff.repository_url
}

output "ecr_repository_envios_url" {
  description = "URL del repositorio ECR para Envios"
  value       = aws_ecr_repository.envios.repository_url
}

output "ecr_repository_frontend_url" {
  description = "URL del repositorio ECR para el Frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.main.name}"
}
output "api_gateway_url" {
  description = "URL de invocación base del AWS API Gateway"
  value       = aws_apigatewayv2_api.rutaexpress_api.api_endpoint
}
