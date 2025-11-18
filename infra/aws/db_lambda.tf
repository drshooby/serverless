# Existing archive
data "archive_file" "db_func_files" {
  type        = "zip"
  source_file = "${path.module}/lambda/db/main.py"
  output_path = "${path.module}/lambda/db/db_func.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "db_lambda_role" {
  name = "db-lambda-role"

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

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.db_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_iam_role_policy" "db_secrets_manager_policy" {
  name = "db-lambda-secrets-policy"
  role = aws_iam_role.db_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      }
    ]
  })
}

resource "aws_security_group" "lambda_sg" {
  name   = "lambda-vpc-sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda function
resource "aws_lambda_function" "db_func" {
  filename         = data.archive_file.db_func_files.output_path
  function_name    = "db-function"
  role             = aws_iam_role.db_lambda_role.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.db_func_files.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  layers = [aws_lambda_layer_version.psycopg_layer.arn]

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = aws_secretsmanager_secret.db_secret.arn
      BUCKET_NAME   = aws_s3_bucket.upload_bucket.id
    }
  }
}
