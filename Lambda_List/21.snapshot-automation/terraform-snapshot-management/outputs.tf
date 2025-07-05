output "tag_snapshot_lambda_arn" {
  value = aws_lambda_function.tag_snapshot.arn
}

output "list_stale_snapshots_lambda_arn" {
  value = aws_lambda_function.list_stale_snapshots.arn
}
