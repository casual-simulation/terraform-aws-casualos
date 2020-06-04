
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "casualos_server" {
  source = "./modules/casualos-micro"

  name = "casualos"

  aws_region  = var.aws_region
  aws_profile = var.aws_profile

  deployer_ssh_public_key = var.deployer_ssh_public_key
  zerotier_network        = var.zerotier_network
  zerotier_api_key        = var.zerotier_api_key
  zerotier_network_cidr   = var.zerotier_network_cidr
}

# The HTTP listener for the load balancer
resource "aws_lb_listener" "load_balancer_http" {
  load_balancer_arn = module.casualos_server.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect to HTTPS by default
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# The HTTPS listener for the load balancer
resource "aws_lb_listener" "load_balancer_https" {
  load_balancer_arn = module.casualos_server.load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = module.casualos_server.instances_target_lb_group.arn
  }
}

data "aws_route53_zone" "primary" {
  name = var.aws_route53_hosted_zone_name
}

# Create an A record for the load balancer
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.aws_route53_subdomain_name
  type    = "A"

  alias {
    name                   = module.casualos_server.load_balancer.dns_name
    zone_id                = module.casualos_server.load_balancer.zone_id
    evaluate_target_health = true
  }
}

# Create a certificate for the domain name
resource "aws_acm_certificate" "cert" {
  domain_name       = aws_route53_record.www.fqdn
  validation_method = "DNS"

  tags = {
    Name = aws_route53_record.www.fqdn
  }

  lifecycle {
    create_before_destroy = true
  }
}
