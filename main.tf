# main.tf

provider "aws" {
  region = var.aws_region  # Change to your region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "iam_access_key_cleanup"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 14
}

# ZIP the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = <<-EOF
      const { 
          IAMClient, 
          ListUsersCommand,
          ListAccessKeysCommand,
          DeleteAccessKeyCommand,
          ListUserTagsCommand 
      } = require('@aws-sdk/client-iam');

      exports.handler = async (event) => {
          const iamClient = new IAMClient({ region: process.env.AWS_REGION });
          
          try {
              const listUsersResponse = await iamClient.send(new ListUsersCommand({}));
              
              for (const user of listUsersResponse.Users) {
                  const listKeysResponse = await iamClient.send(new ListAccessKeysCommand({
                      UserName: user.UserName
                  }));
                  
                  const listTagsResponse = await iamClient.send(new ListUserTagsCommand({
                      UserName: user.UserName
                  }));
                  
                  for (const accessKey of listKeysResponse.AccessKeyMetadata) {
                      const accessKeyId = accessKey.AccessKeyId;
                      
                      const expiryTag = listTagsResponse.Tags.find(
                          tag => tag.Key === 'ExpiryDate-' + accessKeyId
                      );
                      
                      if (expiryTag) {
                          const expiryDate = new Date(expiryTag.Value);
                          const now = new Date();
                          
                          if (now > expiryDate) {
                              await iamClient.send(new DeleteAccessKeyCommand({
                                  UserName: user.UserName,
                                  AccessKeyId: accessKeyId
                              }));
                              
                              console.log('Deleted expired key ' + accessKeyId + ' for user ' + user.UserName);
                          }
                      }
                  }
              }
          } catch (error) {
              console.error('Error:', error);
              throw error;
          }
      };
    EOF
    filename = "index.js"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}_role"  # Changed to use variable

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for the Lambda role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}_policy"  # Changed to use variable
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:ListAccessKeys",
          "iam:ListUserTags",
          "iam:DeleteAccessKey"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "cleanup_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name  # Changed to use variable
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.js.handler"
  runtime         = "nodejs18.x"
  timeout         = 300

  environment {
    variables = {
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
      AWS_REGION = var.aws_region  # Add this to use region variable in Lambda
    }
  }
}

# EventBridge rule
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.function_name}_daily_trigger"  # Changed to use variable
  description         = "Triggers IAM access key cleanup Lambda daily"
  schedule_expression = "cron(0 0 * * ? *)"  # Daily at midnight UTC
}

# EventBridge target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "CleanupLambda"
  arn       = aws_lambda_function.cleanup_lambda.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleanup_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"  # Changed to use variable
  retention_in_days = var.log_retention_days  # Changed to use variable
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.cleanup_lambda.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.daily_trigger.arn
}
