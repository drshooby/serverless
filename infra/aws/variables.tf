variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block."
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Default region."
}

variable "vpc_name" {
  type        = string
  default     = "radiant-vpc"
  description = "VPC name."
}

variable "aws_azs" {
  description = "List of az in the specified region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "Public subnet CIDR blocks."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
  description = "Private subnet CIDR blocks."
}

variable "s3_bucket_name" {
  type    = string
  default = "brutus.ettukube.com"
}

variable "google_auth_client_id" {
  type = string
}

variable "google_auth_client_secret" {
  type = string
}

variable "api_endpoints" {
  description = "API Gateway endpoint configurations"
  type = map(object({
    path_part   = string
    methods     = list(string)
    lambda_arn  = string
    lambda_name = string
  }))
  default = {}
}

variable "rekognition_model_arn" {
  description = "ARN of the Rekognition Custom Labels model"
  type        = string
}

variable "db_user_info" {
  type = object({
    db_name  = string,
    username = string,
    password = string
  })
  sensitive = true
}
