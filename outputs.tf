
output "aws_load_balancer_dns" {
    value = module.casualos_server.aws_load_balancer_dns
}

output "aws_instance_ip" {
    value = module.casualos_server.aws_instance_ip
}

output "domain_name" {
    value = aws_route53_record.www.fqdn
}