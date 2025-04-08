# Casino DevOps Technical Challenge

This repository contains solutions for the Casino DevOps technical challenge, demonstrating infrastructure as code and container orchestration skills.

## Repository Structure

- `/terraform`: AWS infrastructure defined as code (Lambda, DynamoDB, SQS)
- `/kubernetes`: Kubernetes manifests for deploying a web application

## Terraform Solution

The Terraform configuration deploys:
- Lambda function with SQS trigger
- DynamoDB table with infinite scaling
- SQS queue with dead letter queue

### Usage

```bash
# Initialize Terraform
cd terraform
terraform init

# Deploy to development
terraform apply -var-file=environments/dev.tfvars

# Deploy to production
terraform apply -var-file=environments/prod.tfvars

# Apply all resources
kubectl apply -f kubernetes/

# Or apply individual resources
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/pdb.yaml