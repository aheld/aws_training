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
    
    return status


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
                'aws s3 sync s3://{}/{} . --delete'.format(bucket, prefix),
                'cd ..',
                'bash run_scripts.sh'
                ],
            'workingDirectory': ['/var/www/html/{}'.format(prefix)]
        },
        TimeoutSeconds=600
    )

    return response['Command']['Status']
