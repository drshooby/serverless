import json
import boto3
import time
import os
from botocore.exceptions import ClientError

s3_client = boto3.client('s3', region_name='us-east-1')

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        user_email = body['userEmail']
        file_name = body['fileName']
        content_type = body.get('contentType', 'application/octet-stream')
        
        bucket_name = os.environ['UPLOAD_BUCKET']
        s3_key = f"{user_email}/{int(time.time() * 1000)}-{file_name}"
        
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': s3_key,
                'ContentType': content_type
            },
            ExpiresIn=300
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'presignedUrl': presigned_url,
                's3Key': s3_key,
                's3Url': f"https://{bucket_name}.s3.amazonaws.com/{s3_key}"
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
    except Exception as e:
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Origin': '*',
            },
            'body': json.dumps({
                'error': str(e)
            })
        }