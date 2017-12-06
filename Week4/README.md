# Week 4 - EC2

## Goals
- Create an EC2 instance with appropriate permissions to perform analytics on an S3 bucket.


## Preparation
 ### Complete Week 3!
  - [Week 3 README.md](../Week3/README.md) 
 ### Handy tip: CLI autocompletion
  Add to your /etc/bashrc:
  ```
  complete -C aws_completer aws
  ```
  Restart shell.
 ### Set up your account 
  - http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/get-set-up-for-amazon-ec2.html#create-an-iam-user
  - Make sure your default profile is the one you want to use for this tutorial. Alternatively, you can add ```--profile [whatever]``` after aws in every cli command, but that will not be included in these instructions or scripts.
  - Export your account number as a shell variable for use throughout this tutorial.
  ```
  export AWS_ACCT_ID=`aws sts get-caller-identity --output text --query 'Account'`
  ```
  - Create a developer user and export as a shell variable.
  ```
  export AWS_DEV_USER=chrissyTheDev
  ```
### Create a key pair for SSH access
 - See http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/get-set-up-for-amazon-ec2.html#create-a-key-pair
 ```
 export MY_KEY_PAIR=AwsTrainingKey
 ```
### Record your IP address in a shell variable
 ```
 export MY_IP=`curl http://checkip.amazonaws.com/`
 ```

## Create Resources

### Create the bucket
S3 bucket names are global, so come up with a unique name. In the interest of keeping our scripts and commands generic, export it as a shell variable.
```
export MY_S3_BUCKET=cmc-analytics-bucket
```
```
aws s3 mb s3://$MY_S3_BUCKET
```

### Create the permissions

#### Create an 'analytics-developer' group for adding scripts to the bucket
Create a policy document ```bucket-full-access.json```. Here we use cat for the variable interpolation:
```
cat << EOF > bucket-full-access.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*",
                "s3:DeleteObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::$MY_S3_BUCKET",
                "arn:aws:s3:::$MY_S3_BUCKET/*"
            ]
        }
    ]
}
EOF

```

Run the ```create-policy``` command:
```
aws iam create-policy \
  --policy-name bucket-full-access \
  --policy-document file://bucket-full-access.json
```

##### Create a group and assign this new policy
```
aws iam create-group --group-name analytics-developer
```

```
aws iam attach-group-policy \
  --policy-arn arn:aws:iam::$AWS_ACCT_ID:policy/bucket-full-access \
  --group-name analytics-developer
```

##### Assign the developer user to that group
```
aws iam add-user-to-group \
  --group-name analytics-developer \
  --user-name $AWS_DEV_USER
```

#### Create an 'analytics-processor' role for running scripts from the bucket
Create a policy document ```bucket-read-access.json```:

```
cat << EOF > bucket-read-access.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::$MY_S3_BUCKET",
                "arn:aws:s3:::$MY_S3_BUCKET/*"
            ]
        }
    ]
}
EOF

```

Run the ```create-policy``` command:
```
aws iam create-policy \
  --policy-name bucket-read-access \
  --policy-document file://bucket-read-access.json
```

##### Create a role and assign policies
```
aws iam create-role \
  --role-name analytics-processor \
  --assume-role-policy-document file://ec2-assume-role-policy.json
```

Attach our policy for accessing the S3 bucket:
```
aws iam attach-role-policy \
  --role-name analytics-processor \
  --policy-arn arn:aws:iam::$AWS_ACCT_ID:policy/bucket-read-access
```

Attach an AWS managed policy that will allow our EC2 instance to interact with SSM (Systems Manager): 
```
aws iam attach-role-policy \
  --role-name analytics-processor \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM
```

##### Create an instance profile
This is a required step when using roles with EC2. The console will perform this step automatically, but when using the CLI is must be explicit. Instance profiles can only contain one role.

```
aws iam create-instance-profile --instance-profile-name analytics-processor

aws iam add-role-to-instance-profile \
  --instance-profile-name analytics-processor \
  --role-name analytics-processor
```


### Set up the EC2 instance

#### Create a VPC
In most cases, this is not necessary. The current version of EC2 (EC2-VPC) includes a default VPC (of course, you can always create a custom one if you prefer). Older accounts (pre ~2013) may not have a default VPC in certain regions. This is easily confirmed by going to the EC2 page for your account in the console, selecting the appropriate region, and reviewing the information in the top right-hand corner. We will use the default.

#### Create a security group
Security groups control access into and out of an EC2 instance and are region-specific. The default security group allows all outbound traffic, but custom groups must be created to allow other kinds of access (including SSH). Security groups are aggregated - you use them to grant access, not restrict it, so there is never a conflict.

We won't actually need SSH access to our instance for this project, but it can be useful while developing. You may, for instance, need to debug a finicky bash script. For that reason, as well as general interest, it's nice to have the access set up.

More information on setting up rules: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html?icmpid=docs_ec2_console#security-group-rules

```
aws ec2 create-security-group \
  --group-name MySecurityGroup \
  --description "My SSH access security group"

aws ec2 authorize-security-group-ingress \
  --group-name MySecurityGroup \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/24

aws ec2 authorize-security-group-ingress \
  --group-name MySecurityGroup \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name MySecurityGroup \
  --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "Ipv6Ranges": [{"CidrIpv6": "::/0"}]}]'
```

#### Get an AMI
Here we cheat - there are a lot of these and filtering them via the CLI is tricky if you don't know exactly what you are looking for. Find the basic Linux AMI from Launch Instances and export its id in place of 'blah' below.
```
export AMI_ID=blah
```

#### Pick an instance type
https://aws.amazon.com/ec2/instance-types/

#### Run an instance
```
aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type t2.micro \
  --key-name $MY_KEY_PAIR \
  --security-groups MySecurityGroup \
  --iam-instance-profile Name=analytics-processor \
  --user-data file://instance-data.txt \
  --tag-specification 'ResourceType=instance,Tags=[{Key=Department,Value=Analytics}]'
```

**************
__A Note on Volumes:__
We are using default storage here, but AWS has a few options. The AMI you choose will provide a default setup.
* EBS is probably the most flexible, and EBS instances can be snapshotted, detached, and associated with multiple instances. EBS volumes can also be added to running instances. EBS root volumes are deleted on termination by default; additional volumes are not. This is configurable.
* Instance Stores are ephemeral storage on the host machine. This data is gone if the instance is stopped. 
* EFS provides scalable storage that can be common to multiple instances.

*****************

### Add the lambdas

#### Create a role and assign policies
```
aws iam create-role \
  --role-name analytics-runner \
  --assume-role-policy-document file://lambda-assume-role-policy.json
```

Attach managed policy for lambda execution (provides write permissions to Cloudwatch):
```
aws iam attach-role-policy \
  --role-name analytics-runner \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Attach managed policy for EC2 automation:
```
aws iam attach-role-policy \
  --role-name analytics-runner \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole
```

#### Create the lambda function
```
zip lambda-analytics-sync.zip analytics-sync.py
```

Note that this command requires the role arn, whereas others only call for the name.
```
aws lambda create-function \
  --function-name analytics-sync \
  --runtime python3.6 \
  --timeout 63 \
  --role arn:aws:iam::$AWS_ACCT_ID:role/analytics-runner \
  --handler analytics-sync.handler \
  --description "Sync scripts and data from S3 to EC2" \
  --zip-file fileb://lambda-analytics-sync.zip
```

#### Set up the lambda triggers
```
aws lambda add-permission \
  --function-name analytics-sync \
  --statement-id somemadeupid \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$MY_S3_BUCKET \
  --source-account $AWS_ACCT_ID
```

```
cat << EOF > notification.json
{
    "LambdaFunctionConfigurations": [
        {
            "LambdaFunctionArn": "arn:aws:lambda:us-east-1:$AWS_ACCT_ID:function:analytics-sync",
            "Events": [
                "s3:ObjectRemoved:*"
            ],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {
                            "Name": "Prefix",
                            "Value": "data/"
                        }
                    ]
                }
            }
        },
        {
            "LambdaFunctionArn": "arn:aws:lambda:us-east-1:$AWS_ACCT_ID:function:analytics-sync",
            "Events": [
                "s3:ObjectRemoved:*"
            ],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {
                            "Name": "Prefix",
                            "Value": "scripts/"
                        },
                        {
                            "Name": "Suffix",
                            "Value": ".sh"
                        }
                    ]
                }
            }
        },
        {
            "LambdaFunctionArn": "arn:aws:lambda:us-east-1:$AWS_ACCT_ID:function:analytics-sync",
            "Events": [
                "s3:ObjectCreated:*"
            ],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {
                            "Name": "Prefix",
                            "Value": "scripts/"
                        },
                        {
                            "Name": "Suffix",
                            "Value": ".sh"
                        }
                    ]
                }
            }
        },
        {
            "LambdaFunctionArn": "arn:aws:lambda:us-east-1:$AWS_ACCT_ID:function:analytics-sync",
            "Events": [
                "s3:ObjectCreated:*"
            ],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {
                            "Name": "Prefix",
                            "Value": "data/"
                        }
                    ]
                }
            }
        }
    ]
}
EOF

```

```
aws s3api put-bucket-notification-configuration \
  --bucket $MY_S3_BUCKET \
  --notification-configuration file://notification.json
```

## Make it do stuff

### Add a script

### Add some data



