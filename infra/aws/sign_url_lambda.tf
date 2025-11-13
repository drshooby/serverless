# Existing archive
data "archive_file" "s3_signed_func_files" {
  type        = "zip"
  source_file = "${path.module}/lambda/s3_signed/main.py"
  output_path = "${path.module}/lambda/s3_signed/s3_signed.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "s3_signed_lambda_role" {
  name = "s3-signed-lambda-role"

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

# IAM policy for S3 and CloudWatch
resource "aws_iam_role_policy" "s3_signed_lambda_policy" {
  name = "s3-signed-lambda-policy"
  role = aws_iam_role.s3_signed_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.upload_bucket.arn}/*"
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
resource "aws_lambda_function" "s3_signed_func" {
  filename         = data.archive_file.s3_signed_func_files.output_path
  function_name    = "s3-signed-function"
  role             = aws_iam_role.s3_signed_lambda_role.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.s3_signed_func_files.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      UPLOAD_BUCKET = aws_s3_bucket.upload_bucket.id
    }
  }
}
