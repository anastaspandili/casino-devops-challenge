# variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "casino"
}

variable "lambda_payload_filename" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = "lambda_function_payload.zip"
}

# outputs.tf
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.casino_lambda.function_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.casino_table.name
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.casino_queue.url
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = aws_sqs_queue.casino_dlq.url
}