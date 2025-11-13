resource "aws_secretsmanager_secret" "app_config" {
  name        = "app-config"
  description = "App configuration for SPA"
}

// Not actual secrets, just using as middle-man
resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    COGNITO_ENDPOINT     = "https://${aws_cognito_user_pool.cognito_pool.endpoint}"
    COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.cognito_pool_client.id
    COGNITO_REDIRECT_URI = "https://${var.s3_bucket_name}"
    COGNITO_DOMAIN       = "https://${aws_cognito_user_pool_domain.cognito_pool_domain.domain}.auth.${var.aws_region}.amazoncognito.com"
    UPLOAD_BUCKET        = aws_s3_bucket.upload_bucket.id
  })
}
