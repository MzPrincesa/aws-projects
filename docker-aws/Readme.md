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
docker run <image-name>


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

# Move Fargate into the private subnets
Start by creating your vpc endpoints.
So our endpoint set will be:
Service	Endpoint type	Purpose
S3	Gateway	ECR image layer storage
ECR API	Interface	ECR API
ECR DKR	Interface	Docker image registry
CloudWatch Logs	Interface	ECS container logs
DynamoDB	Gateway	Application database
I already have s3 gateway endpoint from another project so we'll skip that.

# Create the endpoint security group & add inbound rule
aws ec2 create-security-group \
  --group-name inner-circle-vpc-endpoints-sg \
  --description "Security group for Inner Circle VPC interface endpoints" \
  --vpc-id YOUR_VPC_ID

aws ec2 authorize-security-group-ingress \
  --group-id ENDPOINT_SG_ID \
  --protocol tcp \
  --port 443 \
  --source-group FARGATE_SG_ID

# Create the ECR endpoints
aws ec2 create-vpc-endpoint \
  --vpc-id YOUR_VPC_ID \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.ecr.api \
  --subnet-ids \
    PRIVATE_SUBNET_1a \
    PRIVATE_SUBNET_1b \
  --security-group-ids ENDPOINT_SG_ID \
  --private-dns-enabled

aws ec2 create-vpc-endpoint \
  --vpc-id YOUR_VPC_ID \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.ecr.dkr \
  --subnet-ids \
    PRIVATE_SUBNET_1a \
    PRIVATE_SUBNET_1b \
  --security-group-ids ENDPOINT_SG_ID \
  --private-dns-enabled

aws ec2 create-vpc-endpoint \
  --vpc-id YOUR_VPC_ID \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.logs \
  --subnet-ids \
    PRIVATE_SUBNET_1a \
    PRIVATE_SUBNET_1b \
  --security-group-ids ENDPOINT_SG_ID \
  --private-dns-enabled

# Create dynamodb endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id YOUR_VPC_ID \
  --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.us-east-1.dynamodb \
  --route-table-ids \
    rtb-private-1 \
    rtb-private-2

# Verify cfreation
aws ec2 describe-vpc-endpoints \
  --filters \
    "Name=vpc-id,Values=YOUR_VPC_ID" \
    "Name=service-name,Values=com.amazonaws.us-east-1.ecr.api,com.amazonaws.us-east-1.ecr.dkr,com.amazonaws.us-east-1.logs,com.amazonaws.us-east-1.dynamodb" \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,VpcEndpointType,State,PrivateDnsEnabled,SubnetIds]' \
  --output json

# Update ECS Service
aws ecs update-service \
  --cluster inner-circle-cluster \
  --service inner-circle-service \
  --network-configuration 'awsvpcConfiguration={subnets=[private-subnet-1a,private-subnet-1b],securityGroups=[FARGATE-SG-ID],assignPublicIp=DISABLED}'

  You can query your network config to ensure "assignPublicIp": "DISABLED" using
  aws ecs describe-services \
  --cluster inner-circle-cluster \
  --services inner-circle-service \
  --query 'services[0].networkConfiguration.awsvpcConfiguration' \
  --output json

# Retest Your application
curl http://YOUR_ALB_DNS_NAME/members
curl http://YOUR_ALB_DNS_NAME/health

# ECR image scanning
Inspect repo config to ensure scanonpush=true
aws ecr describe-repositories \
  --repository-names inner-circle \
  --query 'repositories[0].[repositoryName,repositoryUri,imageScanningConfiguration,scanOnPush,encryptionConfiguration]' \
  --output table
if none(like mine), run
aws ecr put-image-scanning-configuration \
  --repository-name inner-circle \
  --image-scanning-configuration scanOnPush=true

Proceed to scan as Enabling scan-on-push doesn't retroactively scan the image you already pushed.
aws ecr start-image-scan \
  --repository-name inner-circle \
  --image-id imageTag=2.0

After a bit, run:
aws ecr describe-image-scan-findings \
  --repository-name inner-circle \
  --image-id imageTag=2.0 \
  --query '{ScanStatus: imageScanStatus, SeverityCounts: imageScanFindings.findingSeverityCounts}' \
  --output json 

This was my result. Now we have to enable enhanced scanning which uses Amazon Inspector *tears*
    "ScanStatus": {
        "status": "FAILED",
        "description": "Number of vulnerabilities for this image exceeds the maximum supported with Basic Scanning. Please upgrade to Enhanced Scanning to cover all vulnerabilities in the image."
    }

# Enable enhanced scanning
aws ecr put-registry-scanning-configuration \
  --scan-type ENHANCED \
  --rules '[
    {
      "scanFrequency": "CONTINUOUS_SCAN",
      "repositoryFilters": [
        {
          "filter": "inner-circle",
          "filterType": "WILDCARD"
        }
      ]
    }
  ]'

Give it some time and re-run 
aws ecr describe-image-scan-findings \
  --repository-name inner-circle \
  --image-id imageTag=2.0 \
  --query '{ScanStatus: imageScanStatus, SeverityCounts: imageScanFindings.findingSeverityCounts}' \
  --output json

Found some vulns. Let's do soem security exercises.
This is pretty much the idea
Finding
   ↓
Affected package
   ↓
Where did package come from?
   ↓
Is there a fix?
   ↓
Can we upgrade?
   ↓
Does upgrading break the application?
   ↓
Rebuild
   ↓
Rescan
   ↓
Compare findings
Pretty much risk-based vuln mgt

# Inspect critical fiindings
aws ecr describe-image-scan-findings \
  --repository-name inner-circle \
  --image-id imageTag=2.0 \
  --query 'imageScanFindings.enhancedFindings[?severity==`CRITICAL`].[packageVulnerabilityDetails.vulnerabilityId,packageVulnerabilityDetails.packageName,packageVulnerabilityDetails.packageVersion,packageVulnerabilityDetails.fixedInVersion,title]' \
  --output table

Check out Security-Documentation.md


proceed to push new image to ecr & update task definition

# Update ecs service
aws ecs update-service \
    --cluster inner-circle-cluster \
    --service inner-circle-service \
    --task-definition arn:aws:ecs:us-east-1:343218184480:task-definition/inner-circle:3

# Inspect task health
aws ecs describe-tasks \
  --cluster inner-circle \
  --tasks <TASK-ID-FOR-REVISION-3> \
  --query 'tasks[0].{taskArn:taskArn,lastStatus:lastStatus,desiredStatus:desiredStatus,healthStatus:healthStatus,taskDefinition:taskDefinitionArn,containers:containers[*].{name:name,lastStatus:lastStatus,healthStatus:healthStatus,exitCode:exitCode,reason:reason}}' \
  --output json

Made a chnage too my task definition. added health status for the container and redployed it
aws ecs register-task-definition \
  --cli-input-json file://inner-circle-task-definition.json

# Check container health 
aws ecs describe-tasks \
  --cluster inner-circle-cluster \
  --tasks <new-task-arn> \
  --query 'tasks[0].{lastStatus:lastStatus,healthStatus:healthStatus,containers:containers[*].healthStatus}' \
  --output json

# Stop maually created task 
aws ecs stop-task \
  --cluster inner-circle-cluster \
  --task e0dec7deb47b4e46b5951ba52557db06 \
  --reason "Superseded by inner-circle:4, cleaning up manually-started task"

# Tighten policy document
Dynamodb doc tightened to least-priviledge since app only calls ScanCommand (GET /members)
PutCommand (POST /members)
GetCommand (GET /members/:id)

aws iam create-policy-version \
  --policy-arn arn:aws:iam::343218184480:policy/InnerCircleDynamoDBPolicy \
  --policy-document file://inner-circle-dynamodb-policy.json \
  --set-as-default
This command was used because the policy is a manged policy.

Retest your application across those commands

# Secrets managemnt
Our app has no secrets written into it and dynamodb auth is IAM based not credential based. So let's create a placeholder
aws secretsmanager create-secret \
  --name inner-circle/internal-api-key \
  --description "Internal API key for inner-circle protected routes (placeholder for future auth)" \
  --secret-string '{"INTERNAL_API_KEY":"replace-with-a-real-generated-key"}' 
  generate something realistic rather than a dummy string, so it exercises real formatting. I used openssl rand -hex 32

# Create a policy document for this secret
create  a json file defining the secret policy & deploy to your ecstaskexecutionrole
aws iam put-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name InnerCircleSecretsAccess \
  --policy-document file://internal-api-secrets-policy.json

# Verify deployment 
aws iam get-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name InnerCircleSecretsAccess \
  --query 'PolicyDocument'

# Write the secret into the task definition
Credate a secrets block and define name & valueFrom

 Register the new revision and update the service

# Had to create secrets manager endpoint as i kept havinga  resource initialization error as teh task kept tryinfg to call secrets manager
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-082cc8072634505e1 \
  --service-name com.amazonaws.us-east-1.secretsmanager \
  --vpc-endpoint-type Interface \
  --subnet-ids subnet-0d698b6a64e0c2d52 subnet-06fb679155a3e12ef \
  --security-group-ids sg-0bbfca8016abaead3 \
  --private-dns-enabled

# ALB hardening
Inspect ALB
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:343218184480:loadbalancer/app/inner-circle-alb/4ad91183b9f4e513 \
  --output table

Inspect listener
aws elbv2 describe-listeners \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:343218184480:loadbalancer/app/inner-circle-alb/4ad91183b9f4e513 \
  --output json

Inspect SG
aws ec2 describe-security-groups \
  --group-ids sg-0e3f55f619c354e35 \
  --query 'SecurityGroups[0].IpPermissions' \
  --output json

# Enable deletion protection
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:343218184480:loadbalancer/app/inner-circle-alb/4ad91183b9f4e513 \
  --attributes Key=deletion_protection.enabled,Value=true

# Enable drop_invalid_header_fields
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:343218184480:loadbalancer/app/inner-circle-alb/4ad91183b9f4e513 \
  --attributes Key=routing.http.drop_invalid_header_fields.enabled,Value=true

# Enable S3 Access logging
aws s3api create-bucket \
  --bucket inner-circle-alb-logs-343218184480 \
  --region us-east-1

Create log policy 
Attach policy to bu8cket
aws s3api put-bucket-policy \
  --bucket inner-circle-alb-logs-343218184480 \
  --policy file://alb-logs-bucket-policy.json

Enable logging on the ALB, & point to the bucket:
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:343218184480:loadbalancer/app/inner-circle-alb/4ad91183b9f4e513 \
  --attributes \
    Key=access_logs.s3.enabled,Value=true \
    Key=access_logs.s3.bucket,Value=inner-circle-alb-logs-343218184480

Reconfirm it all worked
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:343218184480:loadbalancer/app/inner-circle-alb/4ad91183b9f4e513 \
  --output table

After 5mins
aws s3 ls s3://inner-circle-alb-logs-343218184480/AWSLogs/343218184480/ --recursive

You can go a step further to ensure your bucket isn't exposed
aws s3api get-public-access-block \
  --bucket inner-circle-alb-logs-343218184480

# ECS Autoscaling
Register the ECS service as a scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/inner-circle-cluster/inner-circle-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 3

# Define & apply the scaling policy(ies) you prefer
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/inner-circle-cluster/inner-circle-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name inner-circle-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://cpu-scaling-policy.json

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/inner-circle-cluster/inner-circle-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name inner-circle-memory-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://memory-scaling-policy.json

Confirm Policy
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/inner-circle-cluster/inner-circle-service \
  --output json

Confirm scalable target
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/inner-circle-cluster/inner-circle-service \
  --output json


# Terraform
Confirm Terraform is installed
terraform -version

# Create TF state bucket
aws s3api create-bucket \
  --bucket inner-circle-terraform-state-343218184480 \
  --region us-east-1

# Enable versioning as it helps riollback to a previous known good state if somwething breaks & block pub access
aws s3api put-bucket-versioning \
  --bucket inner-circle-terraform-state-343218184480 \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket inner-circle-terraform-state-343218184480 \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket inner-circle-terraform-state-343218184480 \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Scaffold the tf project
# Starting with S3
mkdir -p terraform/bootstrap
cd terraform/bootstrap

Step 1- Create `versions.tf`, `providers.tf` & `import.sh` files
Note: State locking prevents two terraform apply runs from corrupting state if run simultaneously. Modern Terraform (1.10+) supports native S3 locking without needing a separate DynamoDB table

Create s3.tf in the same terraform/bootstrap directory and define all the s3 alb bucket configs that match what is already running
Define imports for every resource in the `import.sh` file

# ECR
Confirm config so your hcl file matches exactly what you have
aws ecr describe-repositories \
  --repository-names inner-circle \
  --output json

Create an ecr.tf file.

# Enhanced Scanning
Pull registry configs
aws ecr describe-registry \
  --query 'registryId' \
  --output text

aws ecr get-registry-scanning-configuration \
  --output json

Add config from 2nd output to ecr.tf

Note: Registry-level resources import using the account/registry ID, not a resource name

# Networking
Byt now you should understand why the below are happening
aws ec2 describe-vpcs \
  --vpc-ids vpc-082cc8072634505e1 \
  --output json

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-082cc8072634505e1" \
  --query 'Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,MapPublicIp:MapPublicIpOnLaunch,Tags:Tags}' \
  --output json

aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-082cc8072634505e1" \
  --output json

aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-082cc8072634505e1" \
  --output json

aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-082cc8072634505e1" \
  --output json

aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-082cc8072634505e1" \
  --output json

Create a network.tf & a vpc_endpoints.tf file.
Note: If your main route table is the default one auto-created by AWS alongside the VPC, you can't manage (create or destroy) it with a normal `aws_route_table` resource. Terraform has a dedicated resource for this: `aws_default_route_table`. Secondly, if your deafult sg isn't being used by your infrastrucrture/app, it's better to leave it unmanaged. thirdly this is defined by the vpc id and not the rtb id. 
For the rtb associations, the  format is 'subnet ID/route table ID' or 'gateway ID/route table ID'

# Plan
Run this command at this point if you wish.
terraform plan
P.S. The expected output = No changes. Your infrastructure matches the configuration. Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.

You can run a `terraform state list` command for a sanity check if you wish.

# IAM
As usual, get current state first
# Task role: attached managed policies + trust policy
aws iam get-role --role-name inner-circle-task-role --output json
aws iam list-attached-role-policies --role-name inner-circle-task-role --output json
aws iam list-role-policies --role-name inner-circle-task-role --output json
# customer-managed DynamoDB policy
aws iam get-policy --policy-arn arn:aws:iam::343218184480:policy/InnerCircleDynamoDBPolicy --output json
aws iam get-policy-version \
  --policy-arn arn:aws:iam::343218184480:policy/InnerCircleDynamoDBPolicy \
  --version-id $(aws iam get-policy --policy-arn arn:aws:iam::343218184480:policy/InnerCircleDynamoDBPolicy --query 'Policy.DefaultVersionId' --output text) \
  --output json
# Any inline policies on the task role
aws iam get-role-policy \
  --role-name inner-circle-task-role \
  --policy-name InnerCircleExecuteCommandAccess \
  --output json
# Execution role
aws iam get-role --role-name ecsTaskExecutionRole --output json
aws iam list-attached-role-policies --role-name ecsTaskExecutionRole --output json
aws iam list-role-policies --role-name ecsTaskExecutionRole --output json
aws iam get-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name InnerCircleSecretsAccess \
  --output json

Create iam.tf 
Becuase IAM tends to be finnicky, run `terraform plan` at this point.

# Secrets Mgr
Get current secret metadata
aws secretsmanager describe-secret \
  --secret-id inner-circle/internal-api-key \
  --output json

Get the value
aws secretsmanager get-secret-value \
  --secret-id inner-circle/internal-api-key \
  --query 'SecretString' \
  --output text

Add a variables.tf for the secret value
Create ypur terraform.tfvars file for the secret. Ensure itr is referenced in your .gitignore and never commited.
Add resources to secrets.tf

Import both resources
