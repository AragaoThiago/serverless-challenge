import json
import boto3
from collections import defaultdict

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('FileCounts')

def lambda_handler(event, context):
    # Contador para os tipos de arquivos
    file_counts = defaultdict(int)
    
    # Processar cada mensagem recebida
    for record in event['Records']:
        message_body = json.loads(record['body'])
        print("Parsed message body:", message_body)
        s3_event = message_body['Records'][0]
        
        # Extrair o nome do arquivo do evento do S3
        key = s3_event['s3']['object']['key']
        file_type = key.split('.')[-1]
        
        # Incrementar a contagem para o tipo de arquivo
        file_counts[file_type] += 1

    # Atualizar as contagens no DynamoDB
    for file_type, count in file_counts.items():
        update_file_count_in_dynamodb(file_type, count)

    return {
        'statusCode': 200,
        'body': json.dumps('Successfully processed SQS messages and updated DynamoDB.')
    }

def update_file_count_in_dynamodb(file_type, increment):
    """Atualiza a contagem de tipos de arquivos no DynamoDB."""
    try:
        response = table.update_item(
            Key={'FileType': file_type},
            UpdateExpression='ADD FileCount :inc',
            ExpressionAttributeValues={':inc': increment},
            ReturnValues="UPDATED_NEW"
        )
        print(f"Updated DynamoDB for {file_type}: {response['Attributes']}")
    except Exception as e:
        print(f"Error updating DynamoDB for {file_type}: {str(e)}")
        raise
