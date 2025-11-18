# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "process-upload-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for Step Functions to invoke Lambdas
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "step-functions-execution-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = concat(
          values(aws_lambda_function.process_upload)[*].arn,
          [aws_lambda_function.db_func.arn]
        )
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "process_upload" {
  name     = "process-upload-state-machine"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Process uploaded video: detect kills, generate commentary, create clips"
    StartAt = "Setup"
    States = {
      Setup = {
        Type     = "Task"
        Resource = aws_lambda_function.process_upload["step1"].arn
        Next     = "DetectKills"
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
      }
      DetectKills = {
        Type     = "Task"
        Resource = aws_lambda_function.process_upload["step2"].arn
        Next     = "MergeIntervals"
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 3
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
      }
      MergeIntervals = {
        Type     = "Task"
        Resource = aws_lambda_function.process_upload["step3"].arn
        Next     = "CheckClips"
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
      }
      CheckClips = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.totalClips"
            NumericEquals = 0
            Next          = "NoClipsFound"
          }
        ]
        Default = "GenerateClips"
      }
      NoClipsFound = {
        Type = "Succeed"
      }
      GenerateClips = {
        Type     = "Task"
        Next     = "AddToDatabase"
        Resource = aws_lambda_function.process_upload["step4"].arn
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 3
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
      }
      AddToDatabase = {
        Type     = "Task"
        End      = true
        Resource = aws_lambda_function.db_func.arn
        Parameters = {
          "operation"   = "createVideoRecord"
          "userEmail.$" = "$.email"
          "jobId.$"     = "$$.Execution.Name"
          "inputKey.$"  = "$.videoKey"
          "outputKey.$" = "$.montageKey"
        }
      }
    }
  })
}
