
output "aws_load_balancer_dns" {
    value = aws_lb.load_balancer.dns_name
}

output "aws_instance_ip" {
    value = aws_instance.server.public_ip
}
