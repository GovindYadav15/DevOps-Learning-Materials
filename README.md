# DevOps Learning Materials

This repository is a personal DevOps learning workspace. It contains hands-on examples for infrastructure as code, containers, Kubernetes, CI/CD pipelines, and a complete Node.js backend project wired for Docker, GitHub Actions, AWS ECR, EC2 deployment, and CloudWatch logging.

## Repository Structure

```text
.
|-- AWS CloudFormation/     # AWS infrastructure templates
|-- CI-CD/                  # Jenkins pipeline examples
|-- Docker/                 # Dockerized Node.js practice applications
|-- Kubernetes/             # kind cluster and Kubernetes YAML manifests
|-- Terraform/              # Terraform examples for Azure and AWS
|-- ci-cd-project/          # Full backend project with CI/CD and AWS deployment
|-- .github/workflows/      # GitHub Actions workflows
`-- README.md               # Main repository guide
```

## Topics Covered

- Infrastructure as Code with Terraform and AWS CloudFormation
- Docker image creation and containerized application development
- Docker Compose for multi-container local environments
- Kubernetes basics using kind, Pods, Deployments, ReplicaSets, DaemonSets, Jobs, CronJobs, PersistentVolumes, and PersistentVolumeClaims
- Jenkins pipeline syntax
- GitHub Actions CI/CD for testing, building, pushing Docker images, and deploying to AWS EC2
- AWS ECR, EC2, IAM, CloudWatch Agent, and blue/green container deployment

## AWS CloudFormation

The `AWS CloudFormation/` folder contains YAML templates for learning AWS infrastructure provisioning.

| File | Purpose |
| --- | --- |
| `sample-template.yaml` | Demonstrates parameters, mappings, EC2 instance creation, and stack outputs. |
| `create-s3-bucket.yaml` | Creates a simple S3 bucket. |
| `create-ec2-instance.yaml` | Creates an EC2 instance with a security group that allows SSH. |
| `vpc-and-ec2-setup.yaml` | Creates a VPC, subnet, internet gateway, route table, security group, and EC2 instance. |

These templates are useful for practicing basic CloudFormation concepts such as `Resources`, `Parameters`, `Mappings`, `Outputs`, intrinsic functions, and dependencies between AWS resources.

## Terraform

The `Terraform/` folder contains beginner-friendly Terraform configurations for Azure and AWS.

| Path | Purpose |
| --- | --- |
| `sample.tf` | Creates an Azure resource group in East US and outputs the resource group name. |
| `first-project/main.tf` | Creates an Azure resource group in West Europe. |
| `aws-s3/main.tf` | Uses the AWS provider to create an S3 bucket with tags. |
| `multi-region-deployment/main.tf` | Demonstrates multiple Azure provider aliases for deploying resource groups in East US and West US. |

Example Terraform workflow:

```bash
terraform init
terraform plan
terraform apply
```

Before running these examples, configure the correct cloud credentials and update placeholder values such as subscription IDs, bucket names, regions, and resource names.

## Docker

The `Docker/` folder contains two practice Node.js applications.

### `Docker/todo-api`

A simple Express API designed to run inside a Docker container.

Main files:

- `index.js` starts the server.
- `src/app.js` configures Express, JSON parsing, logging, routes, and health checks.
- `src/routes/todoRoutes.js` provides in-memory todo endpoints.
- `Dockerfile` builds a Node 18 Alpine production image.

Available endpoints:

- `GET /` - returns a container status message.
- `GET /health` - returns health status.
- `GET /api/todos` - lists todos.
- `POST /api/todos` - creates a todo with a `text` field.

Run locally:

```bash
cd Docker/todo-api
npm install
npm start
```

Build and run with Docker:

```bash
docker build -t todo-api .
docker run -p 3000:3000 todo-api
```

### `Docker/test-app`

A basic Express and MongoDB practice app.

Main files:

- `server.js` defines Express routes for adding and reading users from MongoDB.
- `public/index.html` and `public/style.css` provide a simple static frontend.
- `Dockerfile` is an early Docker practice file.
- `mongodb.yaml` defines a MongoDB and mongo-express Docker Compose setup.

This project is useful for practicing local containers, MongoDB connectivity, volumes, environment variables, and multi-container setups.

## Kubernetes

The `Kubernetes/kind-clusters/` folder contains Kubernetes manifests for local practice with kind.

| File or Folder | Purpose |
| --- | --- |
| `test-cluster-setup.yaml` | Defines a kind cluster with one control-plane node and three worker nodes. |
| `nginx/namespace.yml` | Creates the `nginx` namespace. |
| `nginx/pod.yaml` | Creates a basic Nginx Pod. |
| `nginx/replica-set.yaml` | Creates an Nginx ReplicaSet with three replicas. |
| `nginx/deployment.yaml` | Creates an Nginx Deployment with three replicas. |
| `nginx/daemonset.yaml` | Runs Nginx as a DaemonSet. |
| `task.yaml` | Creates a Kubernetes Job using BusyBox. |
| `cron-job.yaml` | Creates a CronJob that runs every minute and copies demo data into backups. |
| `persistent-volume.yaml` | Defines a local hostPath PersistentVolume. |
| `persistent-volume-claim.yaml` | Defines a PersistentVolumeClaim for the local volume. |
| `persistent-deployment.yaml` | Deploys Nginx using the PersistentVolumeClaim. |

Example kind workflow:

```bash
kind create cluster --config Kubernetes/kind-clusters/test-cluster-setup.yaml
kubectl apply -f Kubernetes/kind-clusters/nginx/namespace.yml
kubectl apply -f Kubernetes/kind-clusters/nginx/
```

## CI/CD and Jenkins

The `CI-CD/jenkins/first-demo/jenkinsfile` file contains a minimal Jenkins declarative pipeline.

It uses a `node:16-alpine` Docker agent and runs a simple test stage that prints the Node.js version. This is a starting point for learning Jenkins pipeline syntax, Docker agents, and pipeline stages.

## Full CI/CD Project: Tagify

The `ci-cd-project/` folder contains a more complete backend project named **Tagify**.

Tagify is a Node.js, Express, and MongoDB CMS/blog API with support for users, posts, categories, tags, comments, authentication middleware, upload middleware, and advanced post features.

Important files and folders:

| Path | Purpose |
| --- | --- |
| `app.js` and `server.js` | Main Express application and server startup files. |
| `src/config/db.js` | MongoDB connection configuration. |
| `src/models/` | Mongoose models for users, posts, categories, tags, and comments. |
| `src/controllers/` | API business logic. |
| `src/routes/` | Express route definitions. |
| `src/middlewares/` | Authentication and file upload middleware. |
| `test/health.test.js` | Node.js smoke tests for `/` and `/health`. |
| `Dockerfile` | Multi-stage production Docker build with a health check. |
| `docker-compose.yml` | Local app and MongoDB stack. |
| `scripts/setup-ec2.sh` | Prepares an EC2 host with Docker, Nginx, and CloudWatch Agent. |
| `scripts/provision-aws.sh` | Creates or reuses AWS resources such as ECR, IAM role, security group, and EC2. |
| `scripts/deploy-ec2.sh` | Deploys the app to EC2 using a blue/green container switch. |
| `aws/ec2-ecr-cloudwatch-policy.json` | IAM policy for ECR pull and CloudWatch write permissions. |
| `aws/cloudwatch-agent.json` | CloudWatch Agent configuration. |

Run the project locally:

```bash
cd ci-cd-project
npm install
npm run check
npm test
npm run dev
```

Run with Docker Compose:

```bash
cd ci-cd-project
docker compose up --build
```

The local Docker Compose stack starts:

- The Tagify API on port `4000`
- MongoDB on port `27017`
- A named Docker volume for MongoDB data

## GitHub Actions Workflow

The `.github/workflows/ci-cd-project.yml` workflow runs when files in `ci-cd-project/` or the workflow itself change on `main` or `master`.

Pipeline stages:

1. Install Node.js dependencies with `npm ci`.
2. Run syntax checks with `npm run check`.
3. Run smoke tests with `npm test`.
4. On push events, build a production Docker image.
5. Push the image to Amazon ECR.
6. Deploy the image to AWS EC2 over SSH.

Required GitHub configuration:

- Repository variables: `AWS_REGION`, `ECR_REPOSITORY`
- Repository secrets: `AWS_ROLE_TO_ASSUME`, `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY`, `DB_URL`, `JWT_SECRET`

## Notes

- Some example files contain placeholder values or learning credentials. Replace them before using the code in a real cloud account or production environment.
- The Docker practice folders include `node_modules` directories. In real projects, dependencies are usually excluded from Git and restored with `npm install` or `npm ci`.
- CloudFormation, Terraform, and Kubernetes examples may create real cloud resources or local cluster objects. Review each file before applying it.
- Clean up cloud resources after practice to avoid unexpected charges.

## Suggested Learning Path

1. Start with `Docker/todo-api` to understand Dockerfile basics.
2. Use `Docker/test-app` to practice MongoDB and Docker Compose.
3. Move to `Kubernetes/kind-clusters` to deploy containers into a local Kubernetes cluster.
4. Study `Terraform/` and `AWS CloudFormation/` to compare infrastructure as code tools.
5. Review `CI-CD/jenkins/first-demo/jenkinsfile` for Jenkins basics.
6. Explore `ci-cd-project/` and `.github/workflows/ci-cd-project.yml` to understand an end-to-end CI/CD workflow.

## License

The `ci-cd-project/` folder includes its own MIT license file. Other learning examples in this repository are provided as practice material.
