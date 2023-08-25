terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
    account_id = data.aws_caller_identity.current.account_id
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = var.environment_name
  }
}

# Subnets
resource "aws_subnet" "public_app_subnet1" {
  vpc_id = aws_vpc.vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  cidr_block = var.public_app_subnet1_cidr
  tags = {
    Name = "${var.environment_name} Public App Subnet (AZ1)"
  }
}

resource "aws_subnet" "private_app_subnet1" {
  vpc_id = aws_vpc.vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, 1)
  cidr_block = var.private_app_subnet1_cidr
  tags = {
    Name = "${var.environment_name} Private App Subnet (AZ2)"
  }
}

resource "aws_subnet" "private_db_subnet1" {
  vpc_id = aws_vpc.vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  cidr_block = var.private_db_subnet1_cidr
  tags = {
    Name = "${var.environment_name} Private DB Subnet (AZ2)"
  }
}

resource "aws_subnet" "private_db_subnet2" {
  vpc_id = aws_vpc.vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, 1)
  cidr_block = var.private_db_subnet2_cidr
  tags = {
    Name = "${var.environment_name} Private DB Subnet (AZ2)"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = var.environment_name
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_app_subnet1.id
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

# Default Public Route
resource "aws_route" "default_public_route" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "Public route table"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id = aws_subnet.public_app_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "public_route_table_association1" {
  subnet_id = aws_subnet.private_app_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_route_table_association2" {
  subnet_id = aws_subnet.private_db_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_route_table_association3" {
  subnet_id = aws_subnet.private_db_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Groups
resource "aws_security_group" "bastion_security_group" {
  name = "bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id = aws_vpc.vpc.id
  ingress {
      description = "Allow access from specific CIDR"
      protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_blocks = [var.source_cidr]
    }
#  egress {
#      from_port = 0
#      to_port = 0
#      protocol = "-1"
#      cidr_blocks = ["0.0.0.0/0"]
#  }
}

resource "aws_security_group_rule" "bastion_security_group_rule" {
  type = "egress"
  protocol = "tcp"
  from_port = 22
  to_port = 22
  security_group_id = aws_security_group.bastion_security_group.id
  source_security_group_id = aws_security_group.application_security_group.id
}

resource "aws_security_group" "application_security_group" {
  name = "application-sg"
  description = "Security group for Application Server"
  vpc_id = aws_vpc.vpc.id
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "application_security_group_rule" {
  type = "ingress"
  protocol = "tcp"
  from_port = 22
  to_port = 22
  security_group_id = aws_security_group.application_security_group.id
  source_security_group_id = aws_security_group.bastion_security_group.id
}

# Bastion Instance
resource "aws_instance" "bastion_server" {
  ami = var.bastion_ami_id
  instance_type = var.bastion_instance_type
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  subnet_id = aws_subnet.public_app_subnet1.id
  iam_instance_profile = aws_iam_instance_profile.bastion_instance_profile.id
  key_name = var.key_name
  associate_public_ip_address = "true"

  tags = {
    Name = "BastionServerInstance"
  }
}

# Application Instance
resource "aws_instance" "application_server" {
  ami = var.application_ami_id
  instance_type = var.application_instance_type
  vpc_security_group_ids = [aws_security_group.application_security_group.id]
  subnet_id = aws_subnet.private_app_subnet1.id
  iam_instance_profile = aws_iam_instance_profile.application_instance_profile.id
  key_name = var.key_name

  tags = {
    Name = "ApplicationServerInstance"
  }
}

# IAM Role for Bastion Instance
resource "aws_iam_role" "bastion_instance_role" {
  name = "bastion_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "bastion_instance_profile"
  role = aws_iam_role.bastion_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role = aws_iam_role.bastion_instance_role.name
}

# IAM Role for Application Instance
resource "aws_iam_role" "application_instance_role" {
  name = "application_instance_role"
  managed_policy_arns = [aws_iam_policy.application_s3_write_policy.arn]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "application_instance_profile" {
  name = "application_instance_profile"
  role = aws_iam_role.application_instance_role.name
}

resource "aws_iam_policy" "application_s3_write_policy" {
  name = "application_s3_write_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:ListAllMyBuckets", "s3:ListBucket", "s3:PutObject"]
        Effect = "Allow"
        Resource = "*"
      },
    ]
  })
}

output "account_id" {
  value = local.account_id
}

# S3 Bucket
resource "aws_s3_bucket" "application_log_bucket" {
  bucket = "app-log-bucket-${local.account_id}"
}

# RDS Instance
resource "aws_db_subnet_group" "application_rds_subnet_group" {
  name = "application_rds_subnet_group"
  subnet_ids = [aws_subnet.private_db_subnet1.id, aws_subnet.private_db_subnet2.id]

  tags = {
    Name = "Application DB subnet group"
  }
}

resource "aws_db_instance" "application_rds" {
  allocated_storage = 10
  db_name = "mydb"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t3.micro"
  username = "admin"
  parameter_group_name = "default.mysql5.7"
  storage_encrypted = true
  publicly_accessible = false
  manage_master_user_password = true
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.application_rds_subnet_group.name
}
