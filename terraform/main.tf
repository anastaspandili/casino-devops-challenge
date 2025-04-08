# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "casino-terraform-state"
    key            = "casino-app/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Casino-App"
      ManagedBy   = "Terraform"
    }
  }
}

# SQS Queue
resource "aws_sqs_queue" "casino_queue" {
  name                      = "${var.resource_prefix}-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600 # 4 days
  visibility_timeout_seconds = 30
  
  # Redrive policy for production environment
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.casino_dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Name = "${var.resource_prefix}-queue"
  }
}

# Dead Letter Queue for main SQS
resource "aws_sqs_queue" "casino_dlq" {
  name                      = "${var.resource_prefix}-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "${var.resource_prefix}-dlq"
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "casino_table" {
  name           = "${var.resource_prefix}-table"
  billing_mode   = "PAY_PER_REQUEST" # Enables auto-scaling infinitely
  hash_key       = "ID"
  range_key      = "userId"

  attribute {
    name = "ID"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.resource_prefix}-table"
  }
}

# Lambda Function
resource "aws_lambda_function" "casino_lambda" {
  function_name    = "${var.resource_prefix}-lambda"
  filename         = var.lambda_payload_filename
  source_code_hash = filebase64sha256(var.lambda_payload_filename)
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.casino_table.name
      ENVIRONMENT    = var.environment
    }
  }

  tracing_config {
    mode = "Active" # Enables X-Ray tracing
  }

  tags = {
    Name = "${var.resource_prefix}-lambda"
  }
}

# SQS trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.casino_queue.arn
  function_name    = aws_lambda_function.casino_lambda.function_name
  batch_size       = 10
}

# CloudWatch Log Group with retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.casino_lambda.function_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.resource_prefix}-lambda-logs"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.resource_prefix}-lambda-role"
  }
}

# IAM Policies for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.resource_prefix}-lambda-policy"
  description = "Policy for lambda to access SQS, DynamoDB, CloudWatch, and X-Ray"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.casino_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.casino_table.arn
      }
    ]
  })

  tags = {
    Name = "${var.resource_prefix}-lambda-policy"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}