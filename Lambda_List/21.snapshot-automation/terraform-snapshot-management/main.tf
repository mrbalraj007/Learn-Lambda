resource "aws_iam_role" "lambda_role" {
  name = "snapshot_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "snapshot_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateTags",
          "ec2:DescribeSnapshots",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "tag_snapshot" {
  function_name = "TagSnapshotOnCreate"
  role          = aws_iam_role.lambda_role.arn
  handler       = "tag_snapshot.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  filename      = "${path.module}/lambda/tag_snapshot.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/tag_snapshot.zip")
}

resource "aws_cloudwatch_event_rule" "snapshot_create_rule" {
  name        = "TagSnapshotOnCreateRule"
  description = "Trigger Lambda when EBS snapshot is created"

  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    "detail-type" = ["AWS API Call via CloudTrail"],
    detail      = {
      eventSource = ["ec2.amazonaws.com"],
      eventName   = ["CreateSnapshot"]
    }
  })
}

resource "aws_cloudwatch_event_target" "tag_snapshot_target" {
  rule      = aws_cloudwatch_event_rule.snapshot_create_rule.name
  target_id = "TagSnapshotTarget"
  arn       = aws_lambda_function.tag_snapshot.arn
}

resource "aws_lambda_permission" "allow_eventbridge_to_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tag_snapshot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.snapshot_create_rule.arn
}

resource "aws_lambda_function" "list_stale_snapshots" {
  function_name = "ListStaleSnapshots"
  role          = aws_iam_role.lambda_role.arn
  handler       = "list_stale_snapshots.lambda_handler"
  runtime       = "python3.12"
  timeout       = 120
  filename      = "${path.module}/lambda/list_stale_snapshots.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/list_stale_snapshots.zip")
}
