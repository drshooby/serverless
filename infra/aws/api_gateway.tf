# API Gateway REST API
resource "aws_api_gateway_rest_api" "app_api" {
  name        = "app-config-api"
  description = "API for Cognito configuration"
}

# /api resource
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id
  parent_id   = aws_api_gateway_rest_api.app_api.root_resource_id
  path_part   = "api"
}

# Define all endpoints
locals {
  api_endpoints = {
    cognito = {
      path_part   = "cognito"
      methods     = ["GET"]
      lambda_arn  = aws_lambda_function.cognito_func.invoke_arn
      lambda_name = aws_lambda_function.cognito_func.function_name
    }
    upload = {
      path_part   = "get-upload-url"
      methods     = ["POST"]
      lambda_arn  = aws_lambda_function.s3_signed_func.invoke_arn
      lambda_name = aws_lambda_function.s3_signed_func.function_name
    }
    status = {
      path_part   = "poll"
      methods     = ["POST"]
      lambda_arn  = aws_lambda_function.polling_func.invoke_arn
      lambda_name = aws_lambda_function.polling_func.function_name
    }
    database = {
      path_part   = "videos"
      methods     = ["GET", "POST", "DELETE"]
      lambda_arn  = aws_lambda_function.db_func.invoke_arn
      lambda_name = aws_lambda_function.db_func.function_name
    }
  }
}

# Create resources for each endpoint
resource "aws_api_gateway_resource" "endpoints" {
  for_each = local.api_endpoints

  rest_api_id = aws_api_gateway_rest_api.app_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = each.value.path_part
}

# Create methods for each endpoint
resource "aws_api_gateway_method" "endpoint_methods" {
  for_each = merge([
    for endpoint_key, endpoint in local.api_endpoints : {
      for method in endpoint.methods :
      "${endpoint_key}-${method}" => {
        endpoint_key = endpoint_key
        method       = method
      }
    }
  ]...)

  rest_api_id   = aws_api_gateway_rest_api.app_api.id
  resource_id   = aws_api_gateway_resource.endpoints[each.value.endpoint_key].id
  http_method   = each.value.method
  authorization = "NONE"
}

# Lambda integrations
resource "aws_api_gateway_integration" "endpoint_integrations" {
  for_each = merge([
    for endpoint_key, endpoint in local.api_endpoints : {
      for method in endpoint.methods :
      "${endpoint_key}-${method}" => {
        endpoint_key = endpoint_key
        method       = method
        lambda_arn   = endpoint.lambda_arn
      }
    }
  ]...)

  rest_api_id             = aws_api_gateway_rest_api.app_api.id
  resource_id             = aws_api_gateway_resource.endpoints[each.value.endpoint_key].id
  http_method             = aws_api_gateway_method.endpoint_methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_arn
}

# OPTIONS methods for CORS
resource "aws_api_gateway_method" "options_methods" {
  for_each = local.api_endpoints

  rest_api_id   = aws_api_gateway_rest_api.app_api.id
  resource_id   = aws_api_gateway_resource.endpoints[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock integrations for OPTIONS
resource "aws_api_gateway_integration" "options_integrations" {
  for_each = local.api_endpoints

  rest_api_id = aws_api_gateway_rest_api.app_api.id
  resource_id = aws_api_gateway_resource.endpoints[each.key].id
  http_method = aws_api_gateway_method.options_methods[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = <<EOF
{
  "statusCode": 200
}
EOF
  }
}

# OPTIONS method responses
resource "aws_api_gateway_method_response" "options_responses" {
  for_each = local.api_endpoints

  rest_api_id = aws_api_gateway_rest_api.app_api.id
  resource_id = aws_api_gateway_resource.endpoints[each.key].id
  http_method = aws_api_gateway_method.options_methods[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS integration response
resource "aws_api_gateway_integration_response" "options_integration_responses" {
  for_each = local.api_endpoints

  rest_api_id = aws_api_gateway_rest_api.app_api.id
  resource_id = aws_api_gateway_resource.endpoints[each.key].id
  http_method = aws_api_gateway_method.options_methods[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", concat(each.value.methods, ["OPTIONS"]))}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [
    aws_api_gateway_method_response.options_responses,
    aws_api_gateway_integration.options_integrations
  ]
}

# Lambda permissions
resource "aws_lambda_permission" "api_gateway_permissions" {
  for_each = local.api_endpoints

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.app_api.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    aws_api_gateway_integration.endpoint_integrations,
    aws_api_gateway_integration.options_integrations
  ]

  rest_api_id = aws_api_gateway_rest_api.app_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.endpoints,
      aws_api_gateway_method.endpoint_methods,
      aws_api_gateway_integration.endpoint_integrations,
      aws_api_gateway_method.options_methods,
      aws_api_gateway_integration.options_integrations,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  stage_name    = "prod"
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.app_api.id
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}
