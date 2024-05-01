import json
import boto3

dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
s3 = boto3.client('s3')

bucket_name = 'number-of-files-per-type-aragao-desafio'
static_page_key = 'index.html'

def lambda_handler(event, context):
    table = dynamodb.Table('FileCounts')

    # Consulta o DynamoDB para obter as contagens de arquivos por tipo
    response = table.scan()

    # Armazenar as métricas coletadas
    metrics_data = response['Items']
    
    # Prepare a página estática
    html_content = "<html><head><title>File Count Metrics</title></head><body>"
    html_content += f"<h1>File Count Metrics</h1><ul>"

    # Enviar métricas para o CloudWatch e construir página HTML
    for item in metrics_data:
        file_type = item['FileType']
        file_count = int(item['FileCount'])

        # Enviar métrica para CloudWatch
        cloudwatch.put_metric_data(
            Namespace='FileTypesMetrics',
            MetricData=[
                {
                    'MetricName': file_type,
                    'Value': file_count,
                    'Unit': 'Count'
                }
            ]
        )

        # Adicionar dados à página HTML
        html_content += f"<li>{file_type}: {file_count}</li>"

    html_content += "</ul></body></html>"

    # Fazer upload da página estática no S3
    s3.put_object(Bucket=bucket_name, Key=static_page_key, Body=html_content, ContentType='text/html')

    return {
        'statusCode': 200,
        'body': json.dumps('Métricas atualizadas e página estática gerada.')
    }
