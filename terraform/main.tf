terraform {
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

# create AWS KeyPair using the local public key file content
resource "aws_key_pair" "autoinfra_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "app_sg" {
  name        = "autoinfra-app-sg"
  description = "Allow SSH and app ports"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "app ports"
    from_port   = 8081
    to_port     = 8099
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.autoinfra_key.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  # user_data writes the public key into /home/ubuntu/.ssh/authorized_keys (default user)
  # and also creates a 'deployer' user and installs the same public key there
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y openjdk-17-jdk git awscli
              # create deployer user
              id -u deployer >/dev/null 2>&1 || useradd -m -s /bin/bash deployer
              mkdir -p /home/deployer/.ssh
              mkdir -p /home/ubuntu/.ssh

              # write public key for both ubuntu and deployer
              cat > /tmp/autoinfra_pubkey <<PUB
              ${file(var.public_key_path)}
              PUB

              chown root:root /tmp/autoinfra_pubkey
              chmod 644 /tmp/autoinfra_pubkey

              cat /tmp/autoinfra_pubkey >> /home/ubuntu/.ssh/authorized_keys || true
              cat /tmp/autoinfra_pubkey >> /home/deployer/.ssh/authorized_keys || true

              chown -R ubuntu:ubuntu /home/ubuntu/.ssh
              chown -R deployer:deployer /home/deployer/.ssh
              chmod 700 /home/ubuntu/.ssh /home/deployer/.ssh
              chmod 600 /home/ubuntu/.ssh/authorized_keys /home/deployer/.ssh/authorized_keys

              mkdir -p /opt/services
              chown deployer:deployer /opt/services
              EOF

  tags = {
    Name = "autoinfra-single-instance"
  }
}

# RDS (Postgres)
resource "aws_db_instance" "postgres" {
  identifier             = "autoinfra-db"
  engine                 = "postgres"
  engine_version         = "16.6"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  tags = { Name = "autoinfra-db" }
}

output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "ssh_key_name" {
  value = aws_key_pair.autoinfra_key.key_name
}
