output "sqs_queue_arn" {
  value = aws_sqs_queue.queue_for_events.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.file_counts.name
}

output "static_site_bucket_name" {
  value = aws_s3_bucket.static_site.bucket
}

output "static_site_url" {
  value = "http://${aws_s3_bucket_website_configuration.static_site.website_endpoint}"
}

