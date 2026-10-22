# ==============================================================================
# AWS API Gateway (HTTP API v2) con Gestion Nativa de CORS en AWS (Issue #52)
# ==============================================================================

resource "aws_apigatewayv2_api" "rutaexpress_api" {
  name          = "${var.project_name}-api-gateway"
  protocol_type = "HTTP"
  description   = "API Gateway HTTP API con CORS gestionado nativamente en AWS para RutaExpress"

  # Configuracion de CORS nativo de AWS API Gateway
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 86400
  }

  tags = {
    Name        = "${var.project_name}-api-gateway"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================================
# Integracion HTTP Proxy hacia ms-rutaexpress-bff en ec2-apps (Puerto 8080)
# ==============================================================================

resource "aws_apigatewayv2_integration" "bff_integration" {
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.ec2_apps.public_ip}:8080/{proxy}"
  integration_method = "ANY"
}

# ==============================================================================
# Rutas: Enrutamiento hacia el BFF para metodos de negocio (excluye OPTIONS
# para permitir que el motor nativo de CORS en API Gateway responda 204 No Content)
# ==============================================================================

resource "aws_apigatewayv2_route" "proxy_routes" {
  for_each  = toset(["GET /{proxy+}", "POST /{proxy+}", "PUT /{proxy+}", "DELETE /{proxy+}", "PATCH /{proxy+}"])
  api_id    = aws_apigatewayv2_api.rutaexpress_api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.bff_integration.id}"
}

# ==============================================================================
# Stage por Defecto con Auto-Deploy
# ==============================================================================

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.rutaexpress_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
    Project     = var.project_name
  }
}
