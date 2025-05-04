output "lambda_function_arn" {
  value = aws_lambda_function.ec2_status_check.arn
}

output "iam_role_arn" {
  value = aws_iam_role.ec2_status_state_check.arn
}