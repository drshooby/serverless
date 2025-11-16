# Enable EventBridge notifications on S3 bucket
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.upload_bucket.id
  eventbridge = true
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "s3_upload" {
  name        = "s3-upload-trigger-step-functions"
  description = "Trigger Step Functions when video uploaded to S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      reason = ["PutObject"]
      bucket = {
        name = [aws_s3_bucket.upload_bucket.id]
      }
    }
  })
}

# EventBridge Target (Step Functions)
resource "aws_cloudwatch_event_target" "step_functions" {
  rule     = aws_cloudwatch_event_rule.s3_upload.name
  arn      = aws_sfn_state_machine.process_upload.arn
  role_arn = aws_iam_role.eventbridge_step_functions_role.arn

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }

    input_template = <<EOF
{
  "bucket": <bucket>,
  "videoKey": <key>,
  "modelArn": "${var.rekognition_model_arn}"
}
EOF
  }


}

# IAM Role for EventBridge to trigger Step Functions
resource "aws_iam_role" "eventbridge_step_functions_role" {
  name = "eventbridge-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_step_functions_policy" {
  name = "eventbridge-step-functions-policy"
  role = aws_iam_role.eventbridge_step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.process_upload.arn
      }
    ]
  })
}
