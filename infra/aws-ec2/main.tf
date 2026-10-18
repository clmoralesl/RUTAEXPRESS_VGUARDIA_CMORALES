# ==============================================================================
# Despliegue Multi-Instancia en AWS (EC2 Apps, EC2 MQ, EC2 Kafka) - Issue #26
# ==============================================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# 1. Red Dedicada: VPC, Subredes y Tablas de Enrutamiento
# ------------------------------------------------------------------------------

resource "aws_vpc" "rutaexpress_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.rutaexpress_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_subnet" "public_apps" {
  vpc_id                  = aws_vpc.rutaexpress_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name    = "${var.project_name}-subnet-apps"
    Tier    = "Public"
    Project = var.project_name
  }
}

resource "aws_subnet" "brokers" {
  vpc_id                  = aws_vpc.rutaexpress_vpc.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name    = "${var.project_name}-subnet-brokers"
    Tier    = "Brokers"
    Project = var.project_name
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.rutaexpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "apps_assoc" {
  subnet_id      = aws_subnet.public_apps.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "brokers_assoc" {
  subnet_id      = aws_subnet.brokers.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------------------------------------------------------------
# 2. Security Groups: Aislamiento Estricto y Segmentacion de Responsabilidades
# ------------------------------------------------------------------------------

# Security Group para la maquina de Aplicaciones (Frontend Nginx HTTPS + BFF + Microservicios)
resource "aws_security_group" "sg_ec2_apps" {
  name        = "${var.project_name}-sg-ec2-apps"
  description = "Permite acceso publico HTTP/HTTPS hacia Nginx y administracion SSH"
  vpc_id      = aws_vpc.rutaexpress_vpc.id

  ingress {
    description = "Acceso seguro HTTPS hacia Nginx Reverse Proxy"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Acceso HTTP para redireccion automatica 301 a HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Administracion remota SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  egress {
    description = "Salida total hacia Internet (Azure AD, Oracle Cloud DB y brokers)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ec2-apps"
    Project = var.project_name
  }
}

# Security Group para el cluster RabbitMQ (ec2-mq)
resource "aws_security_group" "sg_ec2_mq" {
  name        = "${var.project_name}-sg-ec2-mq"
  description = "Aislamiento estricto de RabbitMQ. Puerto AMQP 5672 restringido a ec2-apps"
  vpc_id      = aws_vpc.rutaexpress_vpc.id

  # Regla innegociable: Solo la maquina de aplicaciones puede enviar mensajes AMQP
  ingress {
    description     = "Puerto AMQP 5672 accesible unicamente desde ec2-apps"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2_apps.id]
  }

  ingress {
    description = "RabbitMQ Management UI para monitoreo"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  ingress {
    description = "Administracion remota SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  egress {
    description = "Salida general para descargas de paquetes y docker hub"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ec2-mq"
    Project = var.project_name
  }
}

# Security Group para el cluster Kafka y Zookeeper (ec2-kafka)
resource "aws_security_group" "sg_ec2_kafka" {
  name        = "${var.project_name}-sg-ec2-kafka"
  description = "Aislamiento estricto de Kafka. Puerto 9092 restringido a ec2-apps"
  vpc_id      = aws_vpc.rutaexpress_vpc.id

  # Regla innegociable: Solo ec2-apps puede producir y consumir eventos de Kafka
  ingress {
    description     = "Broker Kafka 9092 accesible exclusivamente desde ec2-apps"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2_apps.id]
  }

  ingress {
    description = "Kafka UI para inspeccion de topicos y grupos de consumo"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  ingress {
    description = "Administracion remota SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  egress {
    description = "Salida general para descargas de paquetes y docker hub"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ec2-kafka"
    Project = var.project_name
  }
}

# ------------------------------------------------------------------------------
# 3. Imagen Base AMI (Ubuntu 22.04 LTS x86_64)
# ------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# 4. Instancia EC2 MQ: Clúster RabbitMQ (puertos 5672, 15672)
# ------------------------------------------------------------------------------

resource "aws_instance" "ec2_mq" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_mq
  subnet_id                   = aws_subnet.brokers.id
  vpc_security_group_ids      = [aws_security_group.sg_ec2_mq.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 25
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = file("${path.module}/scripts/bootstrap-mq.sh")

  tags = {
    Name        = "${var.project_name}-ec2-mq"
    Role        = "RabbitMQ-Cluster"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# 5. Instancia EC2 Kafka: Zookeeper, Apache Kafka y Kafka UI (puertos 9092, 8085)
# ------------------------------------------------------------------------------

resource "aws_instance" "ec2_kafka" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_kafka
  subnet_id                   = aws_subnet.brokers.id
  vpc_security_group_ids      = [aws_security_group.sg_ec2_kafka.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/bootstrap-kafka.sh", {
    AWS_REGION = var.aws_region
  })

  tags = {
    Name        = "${var.project_name}-ec2-kafka"
    Role        = "Kafka-Zookeeper-Cluster"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# 6. Instancia EC2 Apps: Frontend Nginx HTTPS, BFF y Microservicios
# ------------------------------------------------------------------------------

resource "aws_instance" "ec2_apps" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_apps
  subnet_id                   = aws_subnet.public_apps.id
  vpc_security_group_ids      = [aws_security_group.sg_ec2_apps.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 35
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/bootstrap-apps.sh", {
    RABBITMQ_PRIVATE_IP = aws_instance.ec2_mq.private_ip
    KAFKA_PRIVATE_IP    = aws_instance.ec2_kafka.private_ip
  })

  depends_on = [
    aws_instance.ec2_mq,
    aws_instance.ec2_kafka
  ]

  tags = {
    Name        = "${var.project_name}-ec2-apps"
    Role        = "Frontend-BFF-Microservices"
    Project     = var.project_name
    Environment = var.environment
  }
}
