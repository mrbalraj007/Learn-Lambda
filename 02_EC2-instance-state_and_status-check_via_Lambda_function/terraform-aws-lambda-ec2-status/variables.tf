variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "ec2_status_check"
}

variable "lambda_runtime" {
  description = "The runtime for the Lambda function"
  type        = string
  default     = "python3.12"
}

variable "lambda_architecture" {
  description = "The architecture for the Lambda function"
  type        = string
  default     = "x86_64"
}

variable "iam_role_name" {
  description = "The name of the IAM role for the Lambda function"
  type        = string
  default     = "ec2_status_state_check"
}