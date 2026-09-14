data "aws_caller_identity" "current" {}

# ==============================================================================
# RECURSOS NATIVOS DE EKS PARA COMPATIBILIDAD CON AWS ACADEMY LEARNER LAB
# NOTA: Usamos los recursos nativos de AWS (aws_eks_cluster y aws_eks_node_group)
# en lugar del módulo comunitario para evitar la llamada 'iam:GetRole' en el rol 
# 'voclabs', la cual está bloqueada explícitamente en el entorno de estudiante.
# ==============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.eks_cluster_role_name}"
  version  = "1.30"

  vpc_config {
    subnet_ids             = module.vpc.private_subnets
    endpoint_public_access = true
  }

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "node-group-general"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.eks_node_role_name}"
  subnet_ids      = module.vpc.private_subnets

  # Para Kubernetes 1.30+, AWS requiere el AMI de Amazon Linux 2023 (AL2023_x86_64_STANDARD)
  ami_type = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}
