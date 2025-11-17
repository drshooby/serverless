import boto3
import json
import os
import traceback
from datetime import datetime, timezone

client = boto3.client('stepfunctions')

def lambda_handler(event, context):
    try:
        # Parse job ID from request
        if 'body' in event:
            body = json.loads(event['body'])
            job_id = body.get('jobId')
        else:
            job_id = event.get('jobId')
        
        print(f"Received job_id: {job_id}")
        
        if not job_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                'body': json.dumps({
                    'error': 'jobId is required'
                })
            }
        
        # Construct execution ARN
        state_machine_arn = os.environ.get('STATE_MACHINE_ARN')
        print(f"State machine ARN: {state_machine_arn}")
        
        if not state_machine_arn:
            raise ValueError("STATE_MACHINE_ARN environment variable not set")
        
        execution_arn = f'{state_machine_arn.replace(":stateMachine:", ":execution:")}:job-{job_id}'
        print(f"Looking for execution ARN: {execution_arn}")
        
        # Get execution status
        response = client.describe_execution(executionArn=execution_arn)
        
        status = response['status']
        is_complete = status in ['SUCCEEDED', 'FAILED', 'TIMED_OUT', 'ABORTED']
        
        result = {
            'jobId': job_id,
            'status': status,
            'isComplete': is_complete,
            'startDate': response['startDate'].isoformat()
        }
        
        # Add completion details
        if is_complete:
            result['stopDate'] = response.get('stopDate').isoformat()
            
            if status == 'SUCCEEDED':
                result['output'] = response.get('output')
            elif status == 'FAILED':
                result['error'] = response.get('error')
                result['cause'] = response.get('cause')
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps(result)
        }
        
    except client.exceptions.ExecutionDoesNotExist:
        print(f"Execution not found for job_id: {job_id}")
        return {
            'statusCode': 202,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'jobId': job_id,
                'status': 'PENDING_REDRIVE',
                'isComplete': False,
                'found': False,
                'startDate': datetime.now(timezone.utc).isoformat(),
                'message': 'Execution not started yet'
            })
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        print(traceback.format_exc())
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'error': str(e),
                'type': type(e).__name__
            })
        }