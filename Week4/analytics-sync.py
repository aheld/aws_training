import json
import time

import boto3

def handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    prefix = event['Records'][0]['s3']['object']['key'].split('/')[0]

    try:
        status = sync(bucket, prefix)
    except Exception as e:
        raise e
    
    if status == 'Success':
        return run_scripts(bucket)
    else:
        return 'Processing failed'


def sync(bucket, prefix):
    client = boto3.client('ssm')
    response = client.send_command(
        DocumentName='AWS-RunShellScript',
        Targets=[
            {
                'Key':'tag:Department',
                'Values': ['Analytics']
            }
        ],
        MaxConcurrency='100%',
        MaxErrors='5',
        Parameters={
            'commands': [
                'aws s3 sync s3://{} /{}'.format(bucket, prefix) --delete
                ],
            'executionTimeout': ['3600'],
            'workingDirectory': ['/var/www/html/analytics/{}'.format(prefix)]
        },
        TimeoutSeconds=600
    )

    try:
        command_id = response['Command']['CommandId']
    except KeyError as e:
        raise e
    
    while client.list_commands(CommandId=command_id)['Command']['Status'] \
            in ['Pending', 'InProgress']:
        time.sleep(5)

    return client.list_commands(CommandId=command_id)['Command']['Status']

def run_scripts(bucket):
    client = boto3.client('ssm')
    response = client.send_command(
        DocumentName='AWS-RunShellScript',
        Targets=[
            {
                'Key':'tag:Department',
                'Values': ['Analytics']
            }
        ],
        MaxConcurrency='100%',
        MaxErrors='5',
        Parameters={
            'commands': [
                'bash run_scripts.sh'
                ],
            'executionTimeout': ['3600'],
            'workingDirectory': ['/var/www/html/analytics']
        },
        TimeoutSeconds=600
    )

    return response['Command']['Status']
