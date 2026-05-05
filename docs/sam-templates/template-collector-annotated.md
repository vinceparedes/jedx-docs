# Annotated Collector Template

Source: `template-collector_annotated.yaml`

```yaml
# ============================================================================
# Annotated SAM Template: JEDx Collector Service
# Purpose: Inline comments explain each section/resource and the end-to-end flow.
# Key flow: API Gateway -> Api Lambda (publishes to Kinesis) -> Kinesis ->
#           Validation Lambda -> S3 (success/error) + DynamoDB; Record endpoints
#           interact directly with S3/DynamoDB.
# ============================================================================

AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  jedx-collector

  Sample SAM Template for jedx-collector

# Globals:
#   # Default Lambda settings: 3s timeout and JSON log format.
Globals:
  Function:
    Timeout: 3
    LoggingConfig:
      LogFormat: JSON

# Parameters:
#   # Prefix: namespaces resource names per environment (dev/test/prod).
Parameters:
  Prefix:
    Type: String
    Default: jedx
    Description: Prefix for all resource names


Resources:
# ApplicationResourceGroup:
#   # Resource group for the stack; improves discoverability.
  ApplicationResourceGroup:
    Type: AWS::ResourceGroups::Group
    Properties:
      Name: !Sub '${Prefix}-collector-resource-group'
      ResourceQuery:
        Type: CLOUDFORMATION_STACK_1_0
# ApplicationInsightsMonitoring:
#   # CloudWatch Application Insights enabled for the group.
  ApplicationInsightsMonitoring:
    Type: AWS::ApplicationInsights::Application
    Properties:
      ResourceGroupName: !Sub '${Prefix}-collector-resource-group'
      AutoConfigurationEnabled: 'true' 


#
# Collector Service Components
#    The following resources are part of the jedx-collector service.
#      
# JedxCollectorBucket:
#   # S3 bucket for successfully validated artifacts.
  JedxCollectorBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Prefix}-collector-bucket'
# JedxCollectorErrorBucket:
#   # S3 bucket for validation errors/failed artifacts.
  JedxCollectorErrorBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Prefix}-collector-error-bucket'

# JedxCollectorInputStream:
#   # Kinesis stream receiving events published by the API Lambda.
  JedxCollectorInputStream:
    Type: AWS::Kinesis::Stream
    Properties:
      Name: !Sub '${Prefix}-CollectorInputStream'
      ShardCount: 1

# JedxCollectorApi:
#   # API Gateway exposing /collector endpoints; Cognito authorizer; CORS enabled.
  JedxCollectorApi:
    Type: AWS::Serverless::Api
    Properties:
      Name: !Sub '${Prefix}-collector-api'
      StageName: Prod
      Cors:
        AllowMethods: "'DELETE,GET,HEAD,PUT,POST'"
        AllowHeaders: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
        AllowOrigin: "'*'"
      Auth:
        #DefaultAuthorizer: JedxUserPoolAuthorizer
        Authorizers:
          JedxUserPoolAuthorizer:
            UserPoolArn: arn:aws:cognito-idp:us-east-1:647603630303:userpool/us-east-1_7VKxpkP5l
            Identity:
              Header: Authorization
              ReauthorizeEvery: 0 # Disable reauthorization
# JedxCollectorApiFunction:
#   # ANY /collector; publishes to Kinesis and reads/writes DynamoDB.
  JedxCollectorApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-collector-api-function'
      CodeUri: src/
      Handler: collector_api/app.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCollector:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCollectorApi
            Path: /collector
            Method: ANY
      Environment:
        Variables:
          KINESIS_STREAM_NAME: !Ref JedxCollectorInputStream
          DDB_TABLE_NAME: !Ref JedxCollectorTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - kinesis:PutRecord
              Resource: !GetAtt JedxCollectorInputStream.Arn
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:Query
              Resource: !GetAtt JedxCollectorTable.Arn

# JedxCollectorRecordApiFunction:
#   # /collector/record/{senderId}/{object_type}/{RefId}; interacts with S3 + DynamoDB.
  JedxCollectorRecordApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-collector-record-api-function'
      CodeUri: src/
      Handler: collector_api/record.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCollector:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCollectorApi
            Path: /collector/record/{senderId}/{object_type}/{RefId}
            Method: ANY
      Environment:
        Variables:
          S3_COLLECTOR_BUCKET: !Ref JedxCollectorBucket
          DDB_TABLE_NAME: !Ref JedxCollectorTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
                - s3:GetObjectVersion
                - s3:ListBucket
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Sub '${Prefix}-collector-bucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCollectorTable.Arn
# JedxCarRecordsApiFunction:
#   # /collector/records/{senderId}; lists/query via S3 + DynamoDB.
  JedxCarRecordsApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-collector-records-api-function'
      CodeUri: src/
      Handler: collector_api/record.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCar:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCollectorApi
            Path: /collector/records/{senderId}
            Method: ANY
      Environment:
        Variables:
          S3_COLLECTOR_BUCKET: !Ref JedxCollectorBucket
          DDB_TABLE_NAME: !Ref JedxCollectorTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
                - s3:ListBucket
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Sub '${Prefix}-collector-bucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCollectorTable.Arn
# JedxCarUserApiFunction:
#   # POST /collector/login; user/auth flows using DynamoDB.
  JedxCarUserApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-collector-user-api-function'
      CodeUri: src/
      Handler: collector_api/user.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCollector:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCollectorApi
            Path: /collector/login
            Method: POST
      Environment:
        Variables:
          DDB_TABLE_NAME: !Ref JedxCollectorTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCollectorTable.Arn
# CollectorValidationFunction:
#   # Consumes Kinesis; validates; writes success to JedxCollectorBucket, errors to JedxCollectorErrorBucket, and metadata to DynamoDB.
  CollectorValidationFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-collector-validation-function'
      CodeUri: src/
      Handler: collector_validation_lambda/app.lambda_handler
      Runtime: python3.11
      Architectures:
        - x86_64
      Events:
        KinesisEvent:
          Type: Kinesis
          Properties:
            Stream: !GetAtt JedxCollectorInputStream.Arn
            StartingPosition: LATEST
            BatchSize: 100
      Environment:
        Variables:
          S3_COLLECTOR_BUCKET: !Ref JedxCollectorBucket
          S3_COLLECTOR_ERROR_BUCKET: !Ref JedxCollectorErrorBucket
          DDB_TABLE_NAME: !Ref JedxCollectorTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:PutObject
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Ref 'JedxCollectorBucket', '/*']]
            - Effect: Allow
              Action:
                - s3:PutObject
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Ref 'JedxCollectorErrorBucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
              Resource: !GetAtt JedxCollectorTable.Arn

# JedxCollectorTable:
#   # DynamoDB (pk/sk) for metadata/state; PAY_PER_REQUEST.
  JedxCollectorTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${Prefix}-collector-table'
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
        - AttributeName: sk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
        - AttributeName: sk
          KeyType: RANGE
      BillingMode: PAY_PER_REQUEST

# Outputs:
#   # Exposes ARNs for integration/permissions.
Outputs:
  JedxCollectorFunction:
    Description: Jedx Collector Lambda Function ARN
    Value: !GetAtt JedxCollectorApiFunction.Arn
  JedxCollectorFunctionIamRole:
    Description: Implicit IAM Role created for Jedx Collector function
    Value: !GetAtt JedxCollectorApiFunctionRole.Arn

```
