import json
import boto3
from botocore.exceptions import ClientError

# Global scope - persists across warm invocations
secrets_cache = None
secrets_client = boto3.client('secretsmanager')

def get_secrets():
    global secrets_cache
    
    # Check cache first
    if secrets_cache is not None:
        print("Returning cached secrets")
        return secrets_cache
    
    # Not in cache, fetch from Secrets Manager
    print("Fetching secrets from Secrets Manager")
    try:
        response = secrets_client.get_secret_value(SecretId='app-config')
        secret_string = response['SecretString']
        secrets_cache = json.loads(secret_string)
        return secrets_cache
    except ClientError as e:
        print(f"Error fetching secrets: {e}")
        raise

def lambda_handler(event, context):
    try:
        secrets = get_secrets()
        
        cognito_endpoint = secrets.get('COGNITO_ENDPOINT')
        cognito_client_id = secrets.get('COGNITO_CLIENT_ID')
        cognito_redirect_uri = secrets.get('COGNITO_REDIRECT_URI')
        cognito_domain = secrets.get('COGNITO_DOMAIN')
        upload_bucket = secrets.get('UPLOAD_BUCKET')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': cognito_redirect_uri,
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({
                'COGNITO_ENDPOINT': cognito_endpoint,
                'COGNITO_CLIENT_ID': cognito_client_id,
                'COGNITO_REDIRECT_URI': cognito_redirect_uri,
                'COGNITO_DOMAIN': cognito_domain,
                'UPLOAD_BUCKET': upload_bucket
            })
        }
    except Exception as e:
        print(f"Error in lambda_handler: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }