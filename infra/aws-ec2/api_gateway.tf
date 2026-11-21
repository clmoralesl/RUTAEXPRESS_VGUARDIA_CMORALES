# ==============================================================================
# AWS API Gateway (HTTP API v2) con Gestion Nativa de CORS en AWS (Issue #52)
# y JWT Authorizer con Microsoft Entra ID (Issue #101)
# ==============================================================================

resource "aws_apigatewayv2_api" "rutaexpress_api" {
  name          = "${var.project_name}-api-gateway"
  protocol_type = "HTTP"
  description   = "API Gateway HTTP API con CORS gestionado nativamente en AWS para RutaExpress"

  # Configuracion de CORS nativo de AWS API Gateway.
  # Issue #101: allow_headers es explicito porque el comodin de
  # Access-Control-Allow-Headers no cubre la cabecera Authorization (Fetch).
  # Una cabecera nueva enviada por el frontend debe agregarse aqui.
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
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
# JWT Authorizer con Microsoft Entra ID (Issue #101)
# Valida firma, emisor (iss), audiencia (aud) y vigencia (exp, nbf). No valida
# roles: el control de acceso por rol sigue en ms-rutaexpress-bff.
# ==============================================================================

locals {
  jwt_emisor_entra   = "https://sts.windows.net/${lower(var.azure_ad_tenant_id)}/"
  metodos_protegidos = ["GET", "POST", "PUT", "DELETE", "PATCH"]
  metodos_publicos   = ["GET", "POST"]
}

resource "aws_apigatewayv2_authorizer" "entra_jwt" {
  api_id           = aws_apigatewayv2_api.rutaexpress_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-entra-jwt"

  jwt_configuration {
    issuer   = local.jwt_emisor_entra
    audience = var.api_audiencias_jwt
  }
}

# ==============================================================================
# Integracion para rutas publicas: {proxy} captura solo lo que sigue a
# /api/publico/, por lo que el prefijo se reconstruye en la URI.
# ==============================================================================

resource "aws_apigatewayv2_integration" "bff_publico_integration" {
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.ec2_apps.public_ip}:8080/api/publico/{proxy}"
  integration_method = "ANY"
}

# ==============================================================================
# Rutas protegidas por defecto (JWT). Se excluye OPTIONS y no se declara
# $default ni ANY, para que el CORS nativo responda la preflight sin token.
# ==============================================================================

resource "aws_apigatewayv2_route" "proxy_routes" {
  for_each           = toset([for m in local.metodos_protegidos : "${m} /{proxy+}"])
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.bff_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.entra_jwt.id
}

# ==============================================================================
# Rutas publicas sin autorizador: rastreo, salud y (issue #89) cotizador
# ==============================================================================

resource "aws_apigatewayv2_route" "publico_routes" {
  for_each           = toset([for m in local.metodos_publicos : "${m} /api/publico/{proxy+}"])
  api_id             = aws_apigatewayv2_api.rutaexpress_api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.bff_publico_integration.id}"
  authorization_type = "NONE"
}

# ==============================================================================
# Registro de acceso del Gateway (evidencia de rechazos del autorizador).
# Nunca incluir cabeceras de la peticion: evitaria escribir tokens en CloudWatch.
# ==============================================================================

resource "aws_cloudwatch_log_group" "api_gateway_accesos" {
  name              = "/aws/apigateway/${var.project_name}-api-gateway"
  retention_in_days = 14

  tags = {
    Project = var.project_name
  }
}

# ==============================================================================
# Stage por Defecto con Auto-Deploy
# ==============================================================================

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.rutaexpress_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_accesos.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      metodo            = "$context.httpMethod"
      ruta              = "$context.path"
      routeKey          = "$context.routeKey"
      status            = "$context.status"
      integrationStatus = "$context.integrationStatus"
      errorAutorizador  = "$context.authorizer.error"
    })
  }

  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
    Project     = var.project_name
  }
}
