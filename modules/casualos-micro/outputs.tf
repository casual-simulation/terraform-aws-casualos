
output "aws_load_balancer_dns" {
    value = aws_lb.load_balancer.dns_name
}

output "aws_instance_ip" {
    value = aws_instance.server.public_ip
}

output "load_balancer" {
    value = aws_lb.load_balancer
}

output "instances_target_lb_group" {
    value = aws_lb_target_group.instances
}

output "subnet" {
    value = aws_subnet.default.0
}

output "vpc" {
    value = aws_vpc.default
}

output "volume" {
    value = aws_ebs_volume.mongodb
}