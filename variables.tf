variable environment_name {
  description = "An environment name that is prefixed to resource names"
  type = string
  default = "Dev"
}

variable vpc_cidr {
  description = "Please enter the IP range (CIDR notation) for this VPC"
  type = string
  default = "10.20.0.0/16"
}

variable public_app_subnet1_cidr {
  description = "Please enter the IP range (CIDR notation) for the public subnet in the first Availability Zone"
  type = string
  default = "10.20.30.0/26"
}

variable private_app_subnet1_cidr {
  description = "Please enter the IP range (CIDR notation) for the private subnet in the first Availability Zone"
  type = string
  default = "10.20.30.64/26"
}

variable private_db_subnet1_cidr {
  description = "Please enter the IP range (CIDR notation) for the private subnet in the first Availability Zone"
  type = string
  default = "10.20.30.128/26"
}

variable private_db_subnet2_cidr {
  description = "Please enter the IP range (CIDR notation) for the private subnet in the first Availability Zone"
  type = string
  default = "10.20.30.192/26"
}

variable application_ami_id {
  type = string
  default = "ami-04e35eeae7a7c5883"
}

variable bastion_ami_id {
  type = string
  default = "ami-04e35eeae7a7c5883"
}

variable application_instance_type {
  type = string
  default = "t2.micro"
}

variable bastion_instance_type {
  type = string
  default = "t2.micro"
}

variable source_cidr {
  description = "Source CIDR Block"
  type = string
  default = "97.118.147.136/32"
}

variable key_name {
  description = "SSH Key Name"
  type = string
}