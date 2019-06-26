#!/usr/bin/env bash
#echo -n "Enter ToolsAccount > "
#read ToolsAccount
echo -n "Enter ToolsAccount ProfileName for AWS Cli operations> "
read ToolsAccountProfile
ToolsAccount=$(aws sts get-caller-identity --profile ${ToolsAccountProfile} --query 'Account' --output text | sed  s/\"//g)
echo "Tools Account : ${ToolsAccount}"


#echo -n "Enter Dev Account > "
#read DevAccount
echo -n "Enter DevAccount ProfileName for AWS Cli operations> "
read DevAccountProfile
DevAccount=$(aws sts get-caller-identity --profile ${DevAccountProfile} --query 'Account' --output text | sed  s/\"//g)
echo "DevAccount : ${DevAccount}"

#echo -n "Enter Test Account > "
#read TestAccount
echo -n "Enter QAAccount ProfileName for AWS Cli operations> "
read TestAccountProfile
TestAccount=$(aws sts get-caller-identity --profile ${TestAccountProfile} --query 'Account' --output text | sed  s/\"//g)
echo "QAAccount : ${TestAccount}"

#echo -n "Enter Prod Account > "
#read ProdAccount
echo -n "Enter ProdAccount ProfileName for AWS Cli operations> "
read ProdAccountProfile
ProdAccount=$(aws sts get-caller-identity --profile ${ProdAccountProfile} --query 'Account' --output text | sed  s/\"//g)
echo "ProdAccount : ${ProdAccount}"

aws cloudformation deploy --stack-name pre-reqs --template-file ToolsAcct/pre-reqs.yaml --parameter-overrides DevAccount=$DevAccount TestAccount=$TestAccount ProductionAccount=$ProdAccount --profile $ToolsAccountProfile
echo -n "Enter S3 Bucket created from above > "
read S3Bucket

echo -n "Enter CMK ARN created from above > "
read CMKArn

echo -n "Executing in DEV Account"
aws cloudformation deploy --stack-name toolsacct-codepipeline-role --template-file DevAccount/toolsacct-codepipeline-codecommit.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ToolsAccount=$ToolsAccount CMKARN=$CMKArn --profile $DevAccountProfile

echo -n "Executing in TEST Account"
aws cloudformation deploy --stack-name toolsacct-codepipeline-cloudformation-role --template-file TestAccount/toolsacct-codepipeline-cloudformation-deployer.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ToolsAccount=$ToolsAccount CMKARN=$CMKArn  S3Bucket=$S3Bucket --profile $TestAccountProfile

echo -n "Executing in PROD Account"
aws cloudformation deploy --stack-name toolsacct-codepipeline-cloudformation-role --template-file TestAccount/toolsacct-codepipeline-cloudformation-deployer.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ToolsAccount=$ToolsAccount CMKARN=$CMKArn  S3Bucket=$S3Bucket --profile $ProdAccountProfile


echo -n "Creating Pipeline in Tools Account"
aws cloudformation deploy --stack-name sample-lambda-pipeline --template-file ToolsAcct/code-pipeline.yaml --parameter-overrides DevAccount=$DevAccount TestAccount=$TestAccount ProductionAccount=$ProdAccount CMKARN=$CMKArn S3Bucket=$S3Bucket --capabilities CAPABILITY_NAMED_IAM --profile $ToolsAccountProfile

echo -n "Adding Permissions to the CMK"
aws cloudformation deploy --stack-name pre-reqs --template-file ToolsAcct/pre-reqs.yaml --parameter-overrides CodeBuildCondition=true --profile $ToolsAccountProfile

echo -n "Adding Permissions to the Cross Accounts"
aws cloudformation deploy --stack-name sample-lambda-pipeline --template-file ToolsAcct/code-pipeline.yaml --parameter-overrides CrossAccountCondition=true --capabilities CAPABILITY_NAMED_IAM --profile $ToolsAccountProfile
