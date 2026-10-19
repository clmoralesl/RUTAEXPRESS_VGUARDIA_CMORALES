# ==============================================================================
# Outputs de Terraform - Despliegue Multi-Instancia en AWS (Issue #26)
# ==============================================================================

output "ec2_apps_public_ip" {
  description = "Direccion IP publica de la instancia ec2-apps (Frontend Nginx HTTPS y APIs)"
  value       = aws_instance.ec2_apps.public_ip
}

output "ec2_apps_private_ip" {
  description = "Direccion IP privada de la instancia ec2-apps en la VPC"
  value       = aws_instance.ec2_apps.private_ip
}

output "ec2_mq_public_ip" {
  description = "Direccion IP publica de la instancia ec2-mq (Monitoreo RabbitMQ UI)"
  value       = aws_instance.ec2_mq.public_ip
}

output "ec2_mq_private_ip" {
  description = "Direccion IP privada de RabbitMQ (utilizada internamente por ec2-apps)"
  value       = aws_instance.ec2_mq.private_ip
}

output "ec2_kafka_public_ip" {
  description = "Direccion IP publica de la instancia ec2-kafka (Kafka UI)"
  value       = aws_instance.ec2_kafka.public_ip
}

output "ec2_kafka_private_ip" {
  description = "Direccion IP privada del broker Kafka (utilizada internamente por ec2-apps)"
  value       = aws_instance.ec2_kafka.private_ip
}

output "api_gateway_url" {
  description = "URL publica de AWS API Gateway (HTTP API) con CORS gestionado nativamente en AWS"
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}

output "urls_acceso" {
  description = "Puntos de acceso HTTPS y paneles administrativos en la nube"
  value = {
    api_gateway_url  = aws_apigatewayv2_stage.default_stage.invoke_url
    frontend_https   = "https://${aws_instance.ec2_apps.public_ip}/"
    salud_proxy      = "https://${aws_instance.ec2_apps.public_ip}/salud-proxy"
    api_bff_salud    = "https://${aws_instance.ec2_apps.public_ip}/api/publico/salud"
    rabbitmq_mgmt_ui = "http://${aws_instance.ec2_mq.public_ip}:15672/"
    kafka_ui         = "http://${aws_instance.ec2_kafka.public_ip}:8085/"
  }
}

output "comandos_ssh" {
  description = "Comandos de acceso SSH para administracion y revision de logs"
  value = {
    ssh_apps  = "ssh -i ${var.ssh_key_name}.pem ubuntu@${aws_instance.ec2_apps.public_ip}"
    ssh_mq    = "ssh -i ${var.ssh_key_name}.pem ubuntu@${aws_instance.ec2_mq.public_ip}"
    ssh_kafka = "ssh -i ${var.ssh_key_name}.pem ubuntu@${aws_instance.ec2_kafka.public_ip}"
  }
}

output "matriz_seguridad" {
  description = "Resumen de aislamiento de Security Groups"
  value = {
    sg_apps  = aws_security_group.sg_ec2_apps.id
    sg_mq    = "${aws_security_group.sg_ec2_mq.id} (Puerto 5672 restringido a sg_ec2_apps)"
    sg_kafka = "${aws_security_group.sg_ec2_kafka.id} (Puerto 9092 restringido a sg_ec2_apps)"
  }
}
