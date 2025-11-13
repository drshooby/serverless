# Existing archive
data "archive_file" "cognito_func_files" {
  type        = "zip"
  source_file = "${path.module}/lambda/cognito/main.py"
  output_path = "${path.module}/lambda/cognito/cognito_func.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "cognito_lambda_role" {
  name = "cognito-lambda-role"

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

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.cognito_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Secrets Manager access policy
resource "aws_iam_role_policy" "secrets_manager_policy" {
  name = "lambda-secrets-policy"
  role = aws_iam_role.cognito_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.app_config.arn
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "cognito_func" {
  filename         = data.archive_file.cognito_func_files.output_path
  function_name    = "cognito-function"
  role             = aws_iam_role.cognito_lambda_role.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.cognito_func_files.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
}
