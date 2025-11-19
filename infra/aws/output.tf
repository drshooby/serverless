output "spa_uri" {
  value = aws_s3_bucket_website_configuration.cloud_final_bucket.website_endpoint
}

// For app

output "cognito_pool_client_id" {
  value = aws_cognito_user_pool_client.cognito_pool_client.id
}

output "cognito_pool_domain" {
  value = "https://${aws_cognito_user_pool_domain.cognito_pool_domain.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_pool_endpoint" {
  value = "https://${aws_cognito_user_pool.cognito_pool.endpoint}"
}

output "api_endpoint_urls" {
  value = {
    endpoints = {
      for key, endpoint in local.api_endpoints :
      key => "${aws_api_gateway_stage.stage.invoke_url}${aws_api_gateway_resource.api.path}/${endpoint.path_part}"
    }
  }
  description = "API Gateway endpoint URLs"
}

output "api_gateway_base_url" {
  value = "${aws_api_gateway_stage.stage.invoke_url}${aws_api_gateway_resource.api.path}"
}

output "upload_bucket" {
  value = aws_s3_bucket.upload_bucket.id
}
