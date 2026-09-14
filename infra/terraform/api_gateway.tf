# ==============================================================================
# AWS API GATEWAY (HTTP API)
# ==============================================================================

resource "aws_apigatewayv2_api" "rutaexpress_api" {
  name          = "rutaexpress-api"
  protocol_type = "HTTP"
  description   = "API Gateway para RutaExpress con JWT Authorizer de Azure AD"

  # Configuración de CORS requerida para MSAL desde Angular
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    max_age       = 300
  }

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}

# ==============================================================================
# JWT AUTHORIZER (AZURE AD)
# ==============================================================================

resource "aws_apigatewayv2_authorizer" "azure_ad" {
  api_id           = aws_apigatewayv2_api.rutaexpress_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "azure-ad-jwt-authorizer"

  jwt_configuration {
    audience = ["api://${var.azure_ad_client_id}", var.azure_ad_client_id]
    issuer   = "https://sts.windows.net/${var.azure_ad_tenant_id}/"
  }
}

# ==============================================================================
# INTEGRACIÓN (BFF EKS LoadBalancer)
# ==============================================================================

resource "aws_apigatewayv2_integration" "public_integration" {
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${var.bff_lb_url}:8080/api/publico/{proxy}"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_integration" "private_integration" {
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${var.bff_lb_url}:8080/api/{proxy}"
  integration_method = "ANY"
}

# ==============================================================================
# RUTAS
# ==============================================================================

# Rutas públicas (Sin JWT)
resource "aws_apigatewayv2_route" "public_routes" {
  api_id    = aws_apigatewayv2_api.rutaexpress_api.id
  route_key = "ANY /api/publico/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.public_integration.id}"
}

# Rutas protegidas (Con JWT)
resource "aws_apigatewayv2_route" "private_routes" {
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  route_key          = "ANY /api/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.private_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.azure_ad.id
}

# ==============================================================================
# ETAPAS (STAGES)
# ==============================================================================

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.rutaexpress_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Environment = "dev"
    Project     = "RutaExpress"
  }
}
