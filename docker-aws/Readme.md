Build and Push A Docker Image to AWS ECR

## Prerequisites:
A Docker account
Basic knowledge of Docker: use case, commands
AWS account
Basic knowledge of AWS: console, IAM, users, ECS, ECR
A simple web app that we can use for this project

## Docker Setup & Login & Build
You will need to setup docker. Go to the official website and install the setup. 'https://www.docker.com/get-started/'

To check if the installation is successful, execute 'docker --version' in the terminal. It should prompt with the version and build installed in your system.

Note: If you are using GH codespaces (as i did), it is already installed. Just run the version command.

Go to hub.docker.com/signup and create your account. To connect your system with your Docker account, execute docker login in the terminal.


The app was cloned from this repo https://github.com/joshi-kaushal/members-only
But i stripped it down becuase i wasn't inetrested in going through the motions of updating all the dependencies and app code subsequently. Ain't looking to be a Node.jd developer... hehehehe
If you want to receate an updated version, Check your node & nvm versions. then edit your dockerfile & package.json accordingly.

For newbies like me, here is what the depndencies do
Dependency	Where/why	
async	Controller async flow	
bcryptjs	Password hashing	
compression	Response compression	
connect-flash	Flash messages	
cookie-parser	Cookie parsing	
debug	Server debugging	
dotenv	Environment variables	
express	Web framework	
express-session	User sessions	
express-validator	Input validation	
hbs	Express view engine	
helmet	Security headers	
http-errors	HTTP errors	
moment	Date/time handling	
mongoose	MongoDB	
morgan	HTTP request logging	
passport	Authentication	
passport-local	Local username/password strategy	
dateformat	Date formatting

Then proceed to build your image 
docker build -t <image name> .

Proceed to run your container. 

## Create your ecr repo and auth docker to ecr 
aws ecr create-repository \
    --repository-name project-a/sample-repo

aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com

## Tag & push your image to ecr

docker tag <image name> aws_account_id.dkr.ecr.region.amazonaws.com/my-repository:tag
docker push aws_account_id.dkr.ecr.region.amazonaws.com/my-repository:tag

## Create ECS Cluster
aws ecs create-cluster \
    --cluster-name MyCluster

## Create the ECS Task Execution Role & Attach AWS managed policy
Create a json file that contains the trust policy to use for the IAM role.

Create an IAM role named ecsTaskExecutionRole using the trust policy created in the previous step.
aws iam create-role \
      --role-name ecsTaskExecutionRole \
      --assume-role-policy-document file://ecs-task-trust-policy.json

aws iam attach-role-policy \
      --role-name ecsTaskExecutionRole \
      --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

## Create the Fargate Task Definition
Create cloudwatch log group
aws logs create-log-group \
  --log-group-name xxxx

Create your task definition json file

## Register task definition
aws ecs register-task-definition --cli-input-json file://fargate-task.json

## Create your sg & Allow temporary direct HTTP access
aws ec2 create-security-group \
  --group-name xxxx \
  --description "xxxxx" \
  --vpc-id YOUR_VPC_ID \
  --region xxxx

aws ec2 authorize-security-group-ingress \
  --group-id YOUR_SECURITY_GROUP_ID \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0

Launch Fargate task in a public suubnet & confirm it is running

aws ecs run-task \
  --cluster xxxx \
  --task-definition xxxx \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-ID],securityGroups=sg-ID,assignPublicIp=ENABLED}"

aws ecs list-tasks \
  --cluster xxxx

aws ecs describe-tasks \
  --cluster xxxxx \
  --tasks YOUR_TASK_ARN 

## Retrieve public IP
aws ecs describe-tasks \
  --cluster xxxx \
  --tasks YOUR_TASK_ARN \
  --query 'tasks[0].attachments[0].details' \
  --output table

aws ec2 describe-network-interfaces \
  --network-interface-ids YOUR_ENI_ID \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text

## Test IP
http://PUBLIC_IP:3000/ & http://PUBLIC_IP:3000/health

## Create ALB to point to Fargate
aws ec2 create-security-group \
  --group-name inner-circle-alb-sg \
  --description "Security group for Inner Circle ALB" \
  --vpc-id YOUR_VPC_ID

Allow http ingress traffic
aws ec2 authorize-security-group-ingress \
  --group-id YOUR_ALB_SECURITY_GROUP_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

Point alb to fargate
aws ec2 authorize-security-group-ingress \
  --group-id YOUR_FARGATE_SECURITY_GROUP_ID \
  --protocol tcp \
  --port 3000 \
  --source-group YOUR_ALB_SECURITY_GROUP_ID

create target group
aws elbv2 create-target-group \
  --name xxxxx \
  --protocol HTTP \
  --port 3000 \
  --target-type ip \
  --vpc-id YOUR_VPC_ID \
  --health-check-protocol HTTP \
  --health-check-path /health \
  --health-check-port traffic-port

create alb & listener
aws elbv2 create-load-balancer \
  --name inner-circle-alb \
  --subnets subnet-ID-1 subnet-ID-2 \
  --security-groups YOUR_ALB_SECURITY_GROUP_ID \
  --scheme internet-facing \
  --type application

aws elbv2 create-listener \
  --load-balancer-arn YOUR_ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=YOUR_TARGET_GROUP_ARN

## Create ECS service to manage task
aws ecs create-service \
  --cluster xxxx \
  --service-name xxxx \
  --task-definition xxxx \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-ID],securityGroups=[FARGATE_SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=TARGET_GROUP_ARN,containerName=xxxx,containerPort=xxxx"

COnfirm service is running
aws ecs describe-services \
  --cluster inner-circle-cluster \
  --services inner-circle-service \
  --query 'services[0].[status,runningCount,desiredCount,pendingCount]' \
  --output table
Desired output:
ACTIVE
1
1
0

Meaning:

Service:       ACTIVE
Running:       1
Desired:       1
Pending:       0

confirm target health
aws elbv2 describe-target-health \
  --target-group-arn YOUR_TARGET_GROUP_ARN

Test ALB
curl http://YOUR_ALB_DNS_NAME/ & curl http://YOUR_ALB_DNS_NAME/health
Once confirmed to be working, proceed to remove the fargate sg rule 0.0.0.0/0 → Fargate :3000
aws ec2 revoke-security-group-ingress \
  --group-id YOUR_FARGATE_SECURITY_GROUP_ID \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0

You can retest your alb dns name to be sure it still works

## Create DynamoDB Table
aws dynamodb create-table \
    --table-name xxxx \
    --attribute-definitions AttributeName=memberId,AttributeType=S \
    --key-schema AttributeName=memberId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

create ecs task role
aws iam create-role \
  --role-name xxxxx \
  --assume-role-policy-document file://ecs-task-trust-policy.json (used previous policy doc as the statemnt still applies)

Create the DynamoDB least-privilege policy
Create policy json doc

aws iam create-policy \
  --policy-name xxxxDynamoDBPolicy \
  --policy-document file://inner-circle-dynamodb-policy.json

Attach policy to task role
aws iam attach-role-policy \
  --role-name xxxx \
  --policy-arn POLICY_ARN

Added DynamoDB to Inner Circle app
Add AWS SDK
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
modified app.js file to use dynamodb

## Verify app runs locally
npm start
curl http://localhost:3000/health
curl http://localhost:3000/members (tests empty dynamodb table) expected output: {"members":[]}

# Create First memember
curl -X POST http://localhost:3000/members \
  -H "Content-Type: application/json" \
  -d '{"memberId":"001","name":"Test Member","email":"test@example.com"}'

  Test
  curl http://localhost:3000/members
  curl http://localhost:3000/members/001

# Rebuild docker image
docker build -t image_name:2.0 .

Tag image
docker tag image_name:2.0 \
  343218184480.dkr.ecr.us-east-1.amazonaws.com/inner-circle:2.0

Push Image to ECR
docker push \
  aws_account_id.dkr.ecr.region.amazonaws.com/my-repository:tag

Add task role arn to task definition json file
Change image in json file to 2.0

Regisster new task definition json
aws ecs register-task-definition \
  --cli-input-json file://inner-circle-task-definition.json

# Update ECS service
aws ecs update-service \
  --cluster inner-circle-cluster \
  --service inner-circle-service \
  --task-definition inner-circle:2

# Test ALB again
curl http://YOUR_ALB_DNS_NAME/members