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
    Name = "${var.environment_name} Private DB Subnet (AZ1)"
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

# Bastion Cloudwatch
resource "aws_cloudwatch_metric_alarm" "bastion_cpu_alarm" {
  alarm_name = "bastion-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 80
  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions = [aws_sns_topic.application_event.arn]
  ok_actions = [aws_sns_topic.application_event.arn]
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

# Bastion Cloudwatch
resource "aws_cloudwatch_metric_alarm" "application_cpu_alarm" {
  alarm_name = "application-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 80
  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions = [aws_sns_topic.application_event.arn]
  ok_actions = [aws_sns_topic.application_event.arn]
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

# S3 Write access
resource "aws_iam_policy" "application_s3_write_policy" {
  name = "application_s3_write_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:ListAllMyBuckets"]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = ["s3:ListBucket", "s3:PutObject"]
        Effect = "Allow"
        Resource = ["${aws_s3_bucket.application_log_bucket.arn}", "${aws_s3_bucket.application_log_bucket.arn}/*"]
      },
    ]
  })
}

output "account_id" {
  value = local.account_id
}

# S3 Buckets
# S3 Application Log Bucket
resource "aws_s3_bucket" "application_log_bucket" {
  bucket = "app-log-bucket-${local.account_id}"
}

# S3 Application Log Bucket Versioning
resource "aws_s3_bucket_versioning" "application_log_bucket_versioning" {
  bucket = aws_s3_bucket.application_log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Log Bucket
resource "aws_s3_bucket" "log_bucket" {
  bucket = "log-bucket-${local.account_id}"
}

# S3 bucket policy for logging
resource "aws_s3_bucket_policy" "allow_bucket_logging" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = <<EOF

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3ServerAccessLogsPolicy",
            "Effect": "Allow",
            "Principal": {
                "Service": "logging.s3.amazonaws.com"
            },
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "${aws_s3_bucket.log_bucket.arn}/*"
        }
    ]
}
EOF
}

# S3 logging from app log bucket to log bucket
resource "aws_s3_bucket_logging" "example" {
  bucket = aws_s3_bucket.application_log_bucket.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "app/log/"
}

# RDS
# RDS Subnet setup
resource "aws_db_subnet_group" "application_rds_subnet_group" {
  name = "application_rds_subnet_group"
  subnet_ids = [aws_subnet.private_db_subnet1.id, aws_subnet.private_db_subnet2.id]

  tags = {
    Name = "Application DB subnet group"
  }
}

# RDS Instance
resource "aws_db_instance" "application_rds" {
  identifier = "application-rds"
  allocated_storage = 10
  db_name = "mydb"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = var.rds_instance_type
  username = "admin"
  parameter_group_name = "default.mysql5.7"
  storage_encrypted = true
  publicly_accessible = false
  manage_master_user_password = true
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.application_rds_subnet_group.name
  backup_retention_period = 7
  maintenance_window = "Fri:09:00-Fri:09:30"
}

resource "aws_security_group" "application_rds_security_group" {
  name = "application-rds-sg"
  description = "Security group for RDS"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "application_rds_security_group_rule" {
  type = "ingress"
  protocol = "tcp"
  from_port = 3306
  to_port = 3306
  security_group_id = aws_security_group.application_rds_security_group.id
  source_security_group_id = aws_security_group.application_security_group.id
}

# RDS Snapshot
resource "aws_db_snapshot" "application_rds_snapshot" {
  db_instance_identifier = aws_db_instance.application_rds.identifier
  db_snapshot_identifier = "application-db-snapshot"
}

# RDS Cloudwatch
resource "aws_db_event_subscription" "application_rds_event" {
  name = "rds-event-sub"
  sns_topic = aws_sns_topic.application_event.arn

  source_type = "db-instance"
  source_ids = [aws_db_instance.application_rds.identifier]

  event_categories = [
    "availability",
    "deletion",
    "failover",
    "failure",
    "low storage",
    "maintenance",
    "notification",
    "read replica",
    "recovery",
    "restoration",
  ]
}

# RDS Cloudwatch
resource "aws_cloudwatch_metric_alarm" "rds_cpu_alarm" {
  alarm_name = "rds_cpu_alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/RDS"
  period = "600"
  statistic = "Average"
  threshold = 80
  alarm_description = "Average database CPU utilization over last 10 minutes too high"
  alarm_actions = [aws_sns_topic.application_event.arn]
  ok_actions = [aws_sns_topic.application_event.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.application_rds.identifier
  }
}

# SNS
# SNS for alerts
resource "aws_sns_topic" "application_event" {
  name = "application-events-topic"
}

# Cloudwatch Dashboard
resource "aws_cloudwatch_dashboard" "application_dashboard" {
  dashboard_name = "application-dashboard"

  dashboard_body = jsonencode({
        "widgets": [
        {
            "height": 6,
            "width": 12,
            "y": 0,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.bastion_server.id}", { "region": "${var.aws_region}" } ]
                ],
                "period": 300,
                "region": "${var.aws_region}",
                "stat": "Average",
                "title": "Bastion EC2 Instance CPU"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "period": 300,
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${aws_db_instance.application_rds.id}", { "label": "${aws_db_instance.application_rds.id}", "region": "${var.aws_region}" } ]
                ],
                "region": "${var.aws_region}",
                "stat": "Average",
                "title": "Application RDS Instance CPU",
                "yAxis": {
                    "left": {
                        "min": 0
                    }
                },
                "view": "timeSeries",
                "stacked": false
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 0,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.application_server.id}", { "region": "${var.aws_region}" } ]
                ],
                "period": 300,
                "region": "${var.aws_region}",
                "stat": "Average",
                "title": "Application EC2 Instance CPU"
            }
        }
    ]
  })
}