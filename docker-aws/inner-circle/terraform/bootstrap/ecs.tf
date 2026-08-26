resource "aws_ecs_cluster" "main" {
  name = "inner-circle-cluster"
}

resource "aws_ecs_task_definition" "inner_circle" {
  family                   = "inner-circle"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn             = aws_iam_role.inner_circle_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "inner-circle"
      image     = "343218184480.dkr.ecr.us-east-1.amazonaws.com/inner-circle:4.0"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DYNAMODB_TABLE", value = "inner-circle-members" },
        { name = "AWS_REGION", value = "us-east-1" },
      ]

      secrets = [
        {
          name      = "INTERNAL_API_KEY"
          valueFrom = "arn:aws:secretsmanager:us-east-1:343218184480:secret:inner-circle/internal-api-key-rfBQ5z:INTERNAL_API_KEY::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/inner-circle"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"fetch('http://localhost:3000/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

resource "aws_ecs_service" "inner_circle" {
  name            = "inner-circle-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.inner_circle.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  enable_execute_command        = true
  health_check_grace_period_seconds = 0

  network_configuration {
    subnets = [
      aws_subnet.private_1a.id,
      aws_subnet.private_1b.id,
    ]
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.inner_circle.arn
    container_name    = "inner-circle"
    container_port    = 3000
  }

  # desired_count is actively managed by Application Auto Scaling
  # tell Terraform to leave it alone so plan doesn't fight the scaling policies
  lifecycle {
    ignore_changes = [desired_count]
  }
}