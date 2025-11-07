output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "ssh_key_name" {
  description = "AWS key pair name"
  value       = aws_key_pair.autoinfra_key.key_name
}
