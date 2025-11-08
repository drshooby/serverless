resource "random_id" "cognito_domain_prefix" {
  byte_length = 8
}

resource "aws_cognito_user_pool" "cognito_pool" {
  name = "spa-app-pool"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    required                 = true
  }

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_symbols   = true
  }

  auto_verified_attributes = ["email"]
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}

resource "aws_cognito_user_pool_client" "cognito_pool_client" {
  name                                 = "nextapp-cognito-client"
  user_pool_id                         = aws_cognito_user_pool.cognito_pool.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email"]
  callback_urls = [
    "https://brutus.ettukube.com",
    "http://localhost:3000"
  ]
  supported_identity_providers = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "cognito_pool_domain" {
  domain                = random_id.cognito_domain_prefix.hex
  user_pool_id          = aws_cognito_user_pool.cognito_pool.id
  managed_login_version = 2 # Managed UI
}

resource "aws_cognito_managed_login_branding" "cognito_pool_ui" {
  client_id    = aws_cognito_user_pool_client.cognito_pool_client.id
  user_pool_id = aws_cognito_user_pool.cognito_pool.id

  use_cognito_provided_values = true
}
