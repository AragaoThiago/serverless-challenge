variable "aws_region" {
  type        = string
  description = "A região da AWS onde os recursos serão implantados"
  default     = "us-east-1"
}

variable "aws_account_id" {
  type        = string
  description = "ID da conta AWS para a qual os recursos serão implantados"
}

variable "bucket_name_static_site" {
  type        = string
  description = "Nome do bucket S3 que será usado para hospedar a página estática"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Nome da tabela DynamoDB para contagem de arquivos"
  default     = "FileCounts"
}

variable "queue_name" {
  type        = string
  description = "Nome da fila SQS que receberá eventos do S3"
  default     = "queue-for-events"
}

variable "s3_bucket_data_name" {
  type        = string
  description = "Nome do bucket S3 que será usado para armazenar dados e receber eventos"
}

variable "s3_bucket_static_name" {
  type        = string
  description = "Nome do bucket S3 que será usado para o site estático"
}

variable "lambda_processing_name" {
  type        = string
  description = "Nome da função Lambda que processa eventos do SQS"
  default     = "lbda-processing-sqs"
}

variable "lambda_metrics_name" {
  type        = string
  description = "Nome da função Lambda que processa métricas e atualiza o site estático"
  default     = "lbda-metrics"
}
