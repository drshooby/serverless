locals {
  process_upload_steps = {
    step1 = {
      name    = "process-upload-step1-setup"
      path    = "${path.module}/lambda/process_upload/step1/main.py"
      timeout = 30
      memory  = 256
      layers  = []
    }
    step2 = {
      name    = "process-upload-step2-rekognition"
      path    = "${path.module}/lambda/process_upload/step2/main.py"
      timeout = 600
      memory  = 1024
      layers  = [aws_lambda_layer_version.ffmpeg_layer.arn]
    }
    step3 = {
      name    = "process-upload-step3-merge"
      path    = "${path.module}/lambda/process_upload/step3/main.py"
      timeout = 30
      memory  = 256
      layers  = []
    }
    step4 = {
      name    = "process-upload-step4-commentary"
      path    = "${path.module}/lambda/process_upload/step4/main.py"
      timeout = 300
      memory  = 1024
      layers  = [aws_lambda_layer_version.ffmpeg_layer.arn]
    }
  }

  default_handler = "main.lambda_handler"
  default_runtime = "python3.12"
}

resource "aws_iam_role" "process_upload_lambda_role" {
  name = "process-upload-lambda-role"

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

resource "aws_iam_role_policy" "step_functions_lambda_policy" {
  name = "step-functions-lambda-policy"
  role = aws_iam_role.process_upload_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # S3
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.upload_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.upload_bucket.arn
      },
      # Rekognition Custom Labels
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectCustomLabels",
          "rekognition:DescribeProjectVersions"
        ]
        Resource = "*"
      },
      # Bedrock
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-text-express-v1"
      },
      # Polly
      {
        Effect = "Allow"
        Action = [
          "polly:SynthesizeSpeech"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "process_upload_archives" {
  for_each = local.process_upload_steps

  type        = "zip"
  source_file = each.value.path

  output_path = replace(
    each.value.path,
    "main.py",
    "process_func_${each.key}.zip"
  )
}

resource "aws_lambda_function" "process_upload" {
  for_each = local.process_upload_steps

  function_name    = each.value.name
  filename         = data.archive_file.process_upload_archives[each.key].output_path
  source_code_hash = data.archive_file.process_upload_archives[each.key].output_base64sha256

  role    = aws_iam_role.process_upload_lambda_role.arn
  handler = local.default_handler
  runtime = local.default_runtime

  timeout     = each.value.timeout
  memory_size = each.value.memory

  layers = each.value.layers
}
