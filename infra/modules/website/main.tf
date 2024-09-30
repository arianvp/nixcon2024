
module "launch_template" {
  source = "../nixos_launch_template"

  name               = var.name
  vpc_id             = var.vpc_id
  security_group_ids = setunion(var.security_group_ids, [aws_security_group.website.id])
  instance_type      = var.instance_type
  architecture       = var.architecture
  nix_cache          = var.nix_cache
  key_name           = var.key_name
}

output "launch_template" {
  value = module.launch_template.launch_template
}

resource "aws_security_group" "lb" {
  vpc_id = var.vpc_id
}

resource "aws_security_group" "website" {
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "website_allow_lb" {
  security_group_id            = aws_security_group.website.id
  referenced_security_group_id = aws_security_group.lb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "lb" {
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "lb_allow_website" {
  security_group_id            = aws_security_group.lb.id
  referenced_security_group_id = aws_security_group.website.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_lb" "website" {
  name               = "nixcon2024"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = var.public_subnets
}


resource "aws_lb_listener" "website" {
  load_balancer_arn = aws_lb.website.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener_rule" "website" {
  listener_arn = aws_lb_listener.website.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.website.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }

}

resource "aws_lb_target_group" "website" {
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = 80
  health_check {
    path = "/"
  }
}

resource "aws_autoscaling_group" "website" {
  name = "website"

  min_size         = 1
  max_size         = 3
  desired_capacity = 0

  # Makes sure to use the ELB health check for rollout
  # health_check_type = "ELB"
  instance_maintenance_policy {
    max_healthy_percentage = 200
    min_healthy_percentage = 90
  }

  vpc_zone_identifier = var.private_subnets
  launch_template {
    id = module.launch_template.launch_template.id
  }

}

resource "aws_autoscaling_traffic_source_attachment" "website" {
  autoscaling_group_name = aws_autoscaling_group.website.id
  traffic_source {
    type       = "elbv2"
    identifier = aws_lb_target_group.website.arn
  }
}
