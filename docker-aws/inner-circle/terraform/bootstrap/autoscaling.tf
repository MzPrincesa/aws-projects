resource "aws_appautoscaling_target" "ecs_service" {
  service_namespace = "ecs"
  resource_id        = "service/inner-circle-cluster/inner-circle-service"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity        = 1
  max_capacity        = 3
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "inner-circle-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace
  resource_id         = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension  = aws_appautoscaling_target.ecs_service.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = 60.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "inner-circle-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace
  resource_id         = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension  = aws_appautoscaling_target.ecs_service.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}