
output "aws_load_balancer_dns" {
    value = aws_lb.load_balancer.dns_name
}

output "aws_instance_ip" {
    value = aws_instance.server.public_ip
}

output "ebs_volume" {
    value = <<EOM
# volume registration
type = "csi"
id = "mongodb"
name = "mongodb"
external_id = "${aws_ebs_volume.mongodb.id}"
access_mode = "single-node-writer"
attachment_mode = "file-system"
plugin_id = "aws-ebs0"
EOM
}