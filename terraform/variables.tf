variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "public_key_path" {
  description = "Path to public key file to upload to AWS (e.g. ../autoinfra_key.pub)"
}

variable "key_name" {
  description = "AWS keypair name"
  default     = "autoinfra-key"
}

variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for region (change if needed)"
  default     = "ami-0ecb62995f68bb549"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "volume_size" {
  default = 20
}

variable "db_name" { default = "autoinfra" }
variable "db_user" { default = "admin" }
variable "db_password" { description = "RDS master password" }

variable "ssh_cidr" {
  description = "CIDR for SSH access - lock this down for production"
  default     = "0.0.0.0/0"
}
