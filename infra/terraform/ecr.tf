resource "aws_ecr_repository" "bff" {
  name                 = "rutaexpress-bff"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}

resource "aws_ecr_repository" "envios" {
  name                 = "rutaexpress-envios"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "rutaexpress-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}
