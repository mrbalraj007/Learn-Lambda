data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "src/ec2_status_check/lambda_function.py"
  output_path = "src/ec2_status_check/lambda_function.zip"
}
