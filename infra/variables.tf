variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "fmcsa_api_key" {
  type        = string
  description = "FMCSA API key"
  sensitive   = true
}

variable "mongo_uri" {
  type        = string
  description = "MongoDB connection string"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "Database name for Mongo"
  default     = "freight"
}
