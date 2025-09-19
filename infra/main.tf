provider "aws" {
  region = var.aws_region
}

# -------------------------
# IAM Role for Lambda
# -------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

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

  filename         = "${path.module}/eligibility.zip"    # <-- built by package.sh
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

  filename         = "${path.module}/search.zip"        # <-- built by package.sh
  source_code_hash = filebase64sha256("${path.module}/search.zip")

  environment {
    variables = {
      MONGO_URI = var.mongo_uri
      DB_NAME   = var.db_name
    }
  }
}

# -------------------------
# API Gateway
# -------------------------
resource "aws_apigatewayv2_api" "http_api" {
  name          = "freight-broker-api"
  protocol_type = "HTTP"
}

# Integrations
resource "aws_apigatewayv2_integration" "eligibility_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.eligibility.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "search_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.search_loads.invoke_arn
  integration_method = "POST"
}

# Routes
resource "aws_apigatewayv2_route" "eligibility_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /eligibility"
  target    = "integrations/${aws_apigatewayv2_integration.eligibility_integration.id}"
}

resource "aws_apigatewayv2_route" "search_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /search_feasible_loads"
  target    = "integrations/${aws_apigatewayv2_integration.search_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda Permissions
resource "aws_lambda_permission" "eligibility_permission" {
  statement_id  = "AllowAPIGatewayInvokeEligibility"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eligibility.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "search_permission" {
  statement_id  = "AllowAPIGatewayInvokeSearch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_loads.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
