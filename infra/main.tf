provider "aws" {
  region = var.aws_region
}

# -------------------------
# IAM Role for Lambda
# -------------------------
resource "aws_iam_role" "lambda_exec" {
  name_prefix = "lambda_exec_role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -------------------------
# Eligibility Lambda
# -------------------------
resource "aws_lambda_function" "eligibility" {
  function_name = "carrier_eligibility"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename         = "${path.module}/eligibility.zip"
  source_code_hash = filebase64sha256("${path.module}/eligibility.zip")

  environment {
    variables = {
      FMCSA_API_KEY = var.fmcsa_api_key
    }
  }
}

# -------------------------
# Search Loads Lambda
# -------------------------
resource "aws_lambda_function" "search_loads" {
  function_name = "search_feasible_loads"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 5

  filename         = "${path.module}/search.zip"
  source_code_hash = filebase64sha256("${path.module}/search.zip")

  environment {
    variables = {
      MONGO_URI = var.mongo_uri
      DB_NAME   = var.db_name
    }
  }
}


# -------------------------
# REST API Gateway
# -------------------------
resource "aws_api_gateway_rest_api" "freight_broker_api" {
  name        = "freight-broker-api"
  description = "Freight Broker API with API key authentication"
}

# -------------------------
# API Resources
# -------------------------
resource "aws_api_gateway_resource" "eligibility" {
  rest_api_id = aws_api_gateway_rest_api.freight_broker_api.id
  parent_id   = aws_api_gateway_rest_api.freight_broker_api.root_resource_id
  path_part   = "eligibility"
}

resource "aws_api_gateway_resource" "search" {
  rest_api_id = aws_api_gateway_rest_api.freight_broker_api.id
  parent_id   = aws_api_gateway_rest_api.freight_broker_api.root_resource_id
  path_part   = "search_feasible_loads"
}

# -------------------------
# API Methods
# -------------------------
resource "aws_api_gateway_method" "eligibility_get" {
  rest_api_id   = aws_api_gateway_rest_api.freight_broker_api.id
  resource_id   = aws_api_gateway_resource.eligibility.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "search_get" {
  rest_api_id   = aws_api_gateway_rest_api.freight_broker_api.id
  resource_id   = aws_api_gateway_resource.search.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

# -------------------------
# Lambda Integrations
# -------------------------
resource "aws_api_gateway_integration" "eligibility_integration" {
  rest_api_id = aws_api_gateway_rest_api.freight_broker_api.id
  resource_id = aws_api_gateway_resource.eligibility.id
  http_method = aws_api_gateway_method.eligibility_get.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.eligibility.invoke_arn
}

resource "aws_api_gateway_integration" "search_integration" {
  rest_api_id = aws_api_gateway_rest_api.freight_broker_api.id
  resource_id = aws_api_gateway_resource.search.id
  http_method = aws_api_gateway_method.search_get.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.search_loads.invoke_arn
}

# -------------------------
# API Deployment
# -------------------------
resource "aws_api_gateway_deployment" "freight_broker_deployment" {
  depends_on = [
    aws_api_gateway_integration.eligibility_integration,
    aws_api_gateway_integration.search_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.freight_broker_api.id
}

resource "aws_api_gateway_stage" "freight_broker_stage" {
  deployment_id = aws_api_gateway_deployment.freight_broker_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.freight_broker_api.id
  stage_name    = "prod"
}

# -------------------------
# API Key and Usage Plan
# -------------------------
resource "aws_api_gateway_api_key" "freight_broker_key" {
  name = "freight-broker-api-key"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "freight_broker_plan" {
  name = "freight-broker-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.freight_broker_api.id
    stage  = aws_api_gateway_stage.freight_broker_stage.stage_name
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
}

resource "aws_api_gateway_usage_plan_key" "freight_broker_plan_key" {
  key_id        = aws_api_gateway_api_key.freight_broker_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.freight_broker_plan.id
}

# -------------------------
# Lambda Permissions
# -------------------------
resource "aws_lambda_permission" "eligibility_permission" {
  statement_id  = "AllowAPIGatewayInvokeEligibility"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eligibility.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.freight_broker_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "search_permission" {
  statement_id  = "AllowAPIGatewayInvokeSearch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_loads.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.freight_broker_api.execution_arn}/*/*"
}
