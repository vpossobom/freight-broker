output "api_endpoint" {
  description = "Base URL of the REST API Gateway"
  value       = "https://${aws_api_gateway_rest_api.freight_broker_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.freight_broker_stage.stage_name}"
}

output "api_key" {
  description = "API Key for authentication"
  value       = aws_api_gateway_api_key.freight_broker_key.value
  sensitive   = true
}