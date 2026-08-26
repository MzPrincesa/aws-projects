#!/usr/bin/env bash
set -e

echo ">>> Importing S3 resources"

terraform import aws_s3_bucket.alb_logs inner-circle-alb-logs-343218184480
terraform import aws_s3_bucket_versioning.alb_logs inner-circle-alb-logs-343218184480
terraform import aws_s3_bucket_policy.alb_logs inner-circle-alb-logs-343218184480

echo ">>> Importing ECR resources"

terraform import aws_ecr_repository.inner_circle inner-circle
terraform import aws_ecr_registry_scanning_configuration.this 343218184480

echo ">>> Importing networking resources"

terraform import aws_vpc.main vpc-082cc8072634505e1
terraform import aws_internet_gateway.main igw-0a2ef8a52e11e04fd

terraform import aws_subnet.public_1a subnet-039b5acdc43022cf5
terraform import aws_subnet.public_1b subnet-035411becac61fe17
terraform import aws_subnet.private_1a subnet-0d698b6a64e0c2d52
terraform import aws_subnet.private_1b subnet-06fb679155a3e12ef

terraform import aws_default_route_table.main vpc-082cc8072634505e1
terraform import aws_route_table.public rtb-02141705dbc8c3918
terraform import aws_route_table.private_1a rtb-0367bbe4d7f331e62
terraform import aws_route_table.private_1b rtb-0767ed1c385b4add0

terraform import aws_route_table_association.public_1a subnet-039b5acdc43022cf5/rtb-02141705dbc8c3918
terraform import aws_route_table_association.public_1b subnet-035411becac61fe17/rtb-02141705dbc8c3918
terraform import aws_route_table_association.private_1a subnet-0d698b6a64e0c2d52/rtb-0367bbe4d7f331e62
terraform import aws_route_table_association.private_1b subnet-06fb679155a3e12ef/rtb-0767ed1c385b4add0

terraform import aws_security_group.alb_sg sg-0e3f55f619c354e35
terraform import aws_security_group.fargate_sg sg-093601b8018d1fe45
terraform import aws_security_group.vpc_endpoints_sg sg-0bbfca8016abaead3

echo ">>> Importing VPC endpoints"

terraform import aws_vpc_endpoint.s3 vpce-0226685309ec27490
terraform import aws_vpc_endpoint.dynamodb vpce-074bff006d3d4eb30
terraform import aws_vpc_endpoint.ecr_api vpce-0d3adcd51c3109d63
terraform import aws_vpc_endpoint.ecr_dkr vpce-0a589eea2a1affb67
terraform import aws_vpc_endpoint.logs vpce-04219155b797887d5
terraform import aws_vpc_endpoint.secretsmanager vpce-037b51ab7cf0c4804

echo ">>> Importing IAM resources"

terraform import aws_iam_role.inner_circle_task_role inner-circle-task-role
terraform import aws_iam_policy.dynamodb_policy arn:aws:iam::343218184480:policy/InnerCircleDynamoDBPolicy
terraform import aws_iam_role_policy_attachment.task_role_dynamodb inner-circle-task-role/arn:aws:iam::343218184480:policy/InnerCircleDynamoDBPolicy
terraform import aws_iam_role_policy.task_role_execute_command inner-circle-task-role:InnerCircleExecuteCommandAccess

terraform import aws_iam_role.ecs_task_execution_role ecsTaskExecutionRole
terraform import aws_iam_role_policy_attachment.execution_role_managed "ecsTaskExecutionRole/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
terraform import aws_iam_role_policy.execution_role_secrets ecsTaskExecutionRole:InnerCircleSecretsAccess

echo ">>> Importing Secrets Manager"

terraform import aws_secretsmanager_secret.internal_api_key arn:aws:secretsmanager:us-east-1:343218184480:secret:inner-circle/internal-api-key-rfBQ5z
terraform import aws_secretsmanager_secret_version.internal_api_key "arn:aws:secretsmanager:us-east-1:343218184480:secret:inner-circle/internal-api-key-rfBQ5z|36409c88-dc54-46bc-8cf5-7cc0e75bab7d"

echo ">>> All imports complete"