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

resource "aws_secretsmanager_secret" "db_secret" {
  name        = "db-secret"
  description = "Database details for lambda"
}

resource "aws_secretsmanager_secret_version" "db_secret" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username    = var.db_user_info.username
    password    = var.db_user_info.password
    engine      = "postgres"
    host        = module.db.db_instance_address
    port        = 5432
    dbname      = var.db_user_info.db_name
    BUCKET_NAME = aws_s3_bucket.upload_bucket.id
  })
}
