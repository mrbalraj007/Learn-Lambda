resource "aws_lambda_function" "ec2_status_check" {
  function_name    = var.lambda_function_name
  runtime          = var.lambda_runtime
  role             = aws_iam_role.ec2_status_state_check.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  filename         = data.archive_file.lambda_zip.output_path
  architectures    = [var.lambda_architecture]

  environment {
    # Add any environment variables here if needed
  }

  tags = {
    Name = var.lambda_function_name
  }
}