resource "aws_lb" "inner_circle" {
  name               = "inner-circle-alb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1b.id,
  ]

  security_groups = [
    aws_security_group.alb_sg.id,
  ]

  enable_deletion_protection      = true
  drop_invalid_header_fields      = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }
}

resource "aws_lb_target_group" "inner_circle" {
  name        = "inner-circle-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.inner_circle.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inner_circle.arn
  }
}