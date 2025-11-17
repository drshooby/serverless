import json

def lambda_handler(event, context):
    # Validate required fields
    print("Raw event:", json.dumps(event))
    required_fields = ['bucket', 'videoKey', 'modelArn']
    for field in required_fields:
        if field not in event:
            return {
                'statusCode': 400,
                'error': f'Missing required field: {field}'
            }
    
    bucket = event['bucket']
    video_key = event['videoKey']
    model_arn = event['modelArn']
    
    # Extract email from S3 key (e.g., "david@test.com/video.mp4" -> "david@test.com")
    try:
        email = video_key.split('/')[0]
        if '@' not in email:
            raise ValueError("Invalid email format in videoKey")
    except Exception as e:
        return {
            'statusCode': 400,
            'error': f'Could not extract email from videoKey: {str(e)}'
        }
    
    return {
        'bucket': bucket,
        'videoKey': video_key,
        'email': email,
        'modelArn': model_arn
    }