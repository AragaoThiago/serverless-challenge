# Criação da fila SQS
resource "aws_sqs_queue" "queue_for_events" {
  name = "queue-for-events"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowS3ToSendMessages",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action   = "sqs:SendMessage",
        Resource = "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.queue_name}",
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:s3:::${var.s3_bucket_data_name}"
          }
        }
      }
    ]
  })
}

# Criação do DynamoDB
resource "aws_dynamodb_table" "file_counts" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "FileType"

  attribute {
    name = "FileType"
    type = "S"
  }
}

# Criação do bucket de processamento
resource "aws_s3_bucket" "data_for_processing" {
  bucket = var.s3_bucket_data_name
}

resource "aws_s3_bucket_ownership_controls" "data_for_processing" {
  bucket = aws_s3_bucket.data_for_processing.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "data_for_processing" {
  depends_on = [aws_s3_bucket_ownership_controls.data_for_processing]

  bucket = aws_s3_bucket.data_for_processing.id
  acl    = "private"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_for_processing.id

  queue {
    queue_arn = aws_sqs_queue.queue_for_events.arn
    events    = ["s3:ObjectCreated:Put"]
  }
}

# Criação do bucket que servirá as métricas
resource "aws_s3_bucket" "static_site" {
  bucket = var.s3_bucket_static_name
}

resource "aws_s3_bucket_ownership_controls" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "static_site" {
  depends_on = [
    aws_s3_bucket_ownership_controls.static_site,
    aws_s3_bucket_public_access_block.static_site,
  ]

  bucket = aws_s3_bucket.static_site.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.static_site.bucket}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }
}

# Criação da função lambda de processamento
resource "aws_lambda_function" "lbda_processing_sqs" {
  function_name = var.lambda_processing_name
  handler       = "lbda-processing-sqs.lambda_handler"
  role          = aws_iam_role.lbda_processing_sqs_role.arn
  runtime       = "python3.12"

  filename         = "${path.module}/lambda_function/lbda-processing-sqs.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function/lbda-processing-sqs.zip")
}

resource "aws_lambda_permission" "allow_sqs_to_call_lbda_processing_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lbda_processing_sqs.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.queue_for_events.arn
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = aws_sqs_queue.queue_for_events.arn
  function_name    = aws_lambda_function.lbda_processing_sqs.arn
}

# Criação da função lambda de geração de métricas
resource "aws_lambda_function" "lbda_metrics" {
  function_name = var.lambda_metrics_name
  handler       = "lbda-metrics.lambda_handler"
  role          = aws_iam_role.lbda_metrics_role.arn
  runtime       = "python3.12"

  filename         = "${path.module}/lambda_function/lbda-metrics.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function/lbda-metrics.zip")
}

# Regra EventBridge para disparar a função Lambda de métricas
resource "aws_cloudwatch_event_rule" "every_twenty_minutes" {
  name                = "every-twenty-minutes"
  description         = "Dispara a cada 20 minutos"
  schedule_expression = "rate(20 minutes)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule = aws_cloudwatch_event_rule.every_twenty_minutes.name
  arn  = aws_lambda_function.lbda_metrics.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lbda_metrics" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lbda_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_twenty_minutes.arn
}
