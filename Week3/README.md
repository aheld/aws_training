# Week 3 - S3 Website and CDN

## Goals
- Build a scalable website with a national CDN
- Use a group and policy to give write permissiosn to a developer group
- Serve a javascript site with a high lighthouse score for $2.00 / month
  - HTTPS everywhere
  - Minimized
  - Compressed
  - Fast
- Start using AWS parameters to chain commands


## Preperation
 ### Complete Week 2!
  - [Week 2 README.md](../Week2/README.md)
  - Take a look at [JMESPath](http://jmespath.org/specification.html)
  - Install [jq](https://stedolan.github.io/jq/) 


## Create Base Site Infrastructure

### Create the bucket
```
aws s3 mb s3://aws.isourthing.com
aws s3 website s3://aws.isourthing.com 
--index-document index.html --error-document error.html
```

### Copy a file and view it in the browser
```
aws s3 sync --acl public-read --delete s3://aws.isourthing.com
```

### Manually Create a CloudFront CDN distribution
- https://aws.amazon.com/cloudfront/

This will take some time to generate, so let it run and we will move onto granting our restricted user read/write/delete permissions to files in the S3 bucket

### Create a 'isourthing' developer policy

create a policy document ```developer_policy.json``` such as:
```
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
                "arn:aws:s3:::aws.isourthing.com",
                "arn:aws:s3:::aws.isourthing.com/*"
            ]
        }
    ]
}

```
Example run
```
aws iam create-policy --policy-name isourthingDev --policy-document file://developer_policy.json

{
    "Policy": {
        "PolicyName": "isourthingDev",
        "PolicyId": "ANPAI3IHJAVWRXLVGWS6C",
        "Arn": "arn:aws:iam::99999999999:policy/isourthingDev",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "IsAttachable": true,
        "CreateDate": "2017-10-22T14:12:05.554Z",
        "UpdateDate": "2017-10-22T14:12:05.554Z"
    }
}
```

#### Create a group and assign this new policy

```
aws iam create-group --group-name IsOurThingWebMasters
{
    "Group": {
        "Path": "/",
        "GroupName": "IsOurThingWebMasters",
        "GroupId": "AGPAJE4YPDSVB7GQEOKP6",
        "Arn": "arn:aws:iam::99999999999:group/IsOurThingWebMasters",
        "CreateDate": "2017-10-22T14:16:48.267Z"
    }
}
```

```
aws iam attach-group-policy \ 
  --policy-arn arn:aws:iam::99999999999:policy/isourthingDev \
  --group-name IsOurThingWebMasters
```

#### Assign restrictedUser to that group
```
aws iam attach-group-policy \ 
  --policy-arn arn:aws:iam::99999999999:policy/isourthingDev \
  --group-name IsOurThingWebMasters
```
Finally we can test to see if this restricted user can access the website.

```
aws s3 sync --acl public-read --delete s3://aws.isourthing.com --profile restrictedUser
```

#### Review bash script

  Sample script to create and destroy policy and group [tf_script.sh](./tf_script.sh)

  - [jq](https://stedolan.github.io/jq/) + [xargs](https://www.computerhope.com/unix/xargs.htm) are amazing

  ```
  jq '.Statement' developer_policy.json 
  jq '.Statement[].Action' developer_policy.json 
  ```

### Script CloudFront

We want to pull the cloudfront configuraion and use it for a script.  We need to pass a json file to the CLI in order to set all the parameters.

#### Find the Condig for our distro

__aws cloudfront get-distribution-config__ requires an Id, and we need to look for it using ```aws cloudfront list-distributions```


##### Use JMESPATH --query
[JMESPATH](http://jmespath.org/specification.html)
```
aws cloudfront list-distributions --query 'DistributionList.Items[].Origins.Items[].Id'
```

##### Use jq
```
aws cloudfront list-distributions | jq '.DistributionList.Items[] | select( .Origins.Items[].Id == "S3-nrgretail_api") | .Id' -r
```

or 
```
aws cloudfront get-distribution-config \ 
  --id $(aws cloudfront list-distributions | jq '.DistributionList.Items[] | select( .Origins.Items[].Id == "S3-nrgretail_api") | .Id' -r)
```

edit the output and save it to a config file.  Then we can create the distribution using that file

```
aws cloudfront create-distribution --distribution-config file://cf_config.json
```

aws cloudfront tag-resource --resource `jq .Distribution.ARN cf_output.json -r` --tags file://tags.json

# Build a static site 
```
  vue init pwa static_site
  cd static_site/
  npm install
  npm run dev
```

deploy it  
```
  aws s3 sync --acl public-read --delete dist/ s3://aws.isourthing.com
```

Add it to package.json 

```
{
  "scripts": {
    ...
    "deploy": "npm run build && aws s3 sync --acl public-read --delete dist/ s3://aws.isourthing.com"
  }
```
