#!/bin/bash

# Training Form script

ACCOUNT_TO_USE="ReplaceMe"
POLICY_NAME=isourthingDev
GROUP_NAME=IsOurThingWebMasters

# code below
ACCOUNTID=$(aws sts get-caller-identity --query 'Account' --out text)

POLICY_ARN=arn:aws:iam::$ACCOUNTID:policy/$POLICY_NAME

echo "using Account $ACCOUNTID"

if [ $ACCOUNTID != $ACCOUNT_TO_USE ]; then 
    echo 'wrong credentials, you are not using the account you think you are';
    echo "You are hitting account $ACCOUNTID, not $ACCOUNT_TO_USE"
    exit 1;
fi


create_policy(){
    aws iam create-policy --policy-name $POLICY_NAME --policy-document file://developer_policy.json
}

destroy_policy(){
    aws iam delete-policy --policy-arn $POLICY_ARN
}

create_group_and_attach_policy(){
    aws iam create-group --group-name $GROUP_NAME
    aws iam attach-group-policy \
        --policy-arn $POLICY_ARN \
        --group-name $GROUP_NAME
}

add_users_to_group(){
    jq '.Users[]' users.json -r | \
    xargs -n 1 aws iam add-user-to-group --group-name $GROUP_NAME --user-name $1
}

remove_users_from_group(){
    aws iam get-group --group-name $GROUP_NAME | \
     jq '.Users[].UserName' -r | \
        xargs -n 1 aws iam remove-user-from-group --group-name $GROUP_NAME \
            --user-name $1
}

remove_policies_from_group(){
    aws iam list-attached-group-policies --group-name $GROUP_NAME | \
    jq '.AttachedPolicies[].PolicyArn' -r | \
    xargs -n 1 aws iam detach-group-policy --group-name $GROUP_NAME \
        --policy-arn $1
}

destroy_group(){
    remove_users_from_group
    remove_policies_from_group
    aws iam delete-group --group-name $GROUP_NAME
}



case "$1" in
        create)
            echo "Creating your setup";
            create_policy
            create_group_and_attach_policy
            add_users_to_group
            ;;
        destroy)
            echo "Destroying your setup"
            destroy_group
            destroy_policy
            ;;
        *)
            echo $"Usage: $0 {create|destroy}"
            echo "You can create or destroy, the choice is yours"
            exit 1
esac