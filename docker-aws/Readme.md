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
      --assume-role-policy-document file://ecs-tasks-trust-policy.json

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

## Create your sg
aws ec2 create-security-group \
  --group-name xxxx \
  --description "xxxxx" \
  --vpc-id YOUR_VPC_ID \
  --region xxxx



aws ec2 create-security-group \
  --group-name inner-circle-fargate-sg \
  --description "Security group for Inner Circle Fargate task" \
  --vpc-id YOUR_VPC_ID \
  --region us-east-1