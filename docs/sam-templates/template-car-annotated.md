# Annotated CAR Template

Source: `template-car_annotated.yaml`

```yaml
# ============================================================================
# Annotated SAM Template: JEDx CAR Service
# Purpose: Inline comments explain each section/resource and the end-to-end flow.
# Key flow: S3 (input) -> Lambda (S3ToKinesis) -> Kinesis -> Lambda (CarValidation)
#           -> S3 (success/error) + DynamoDB; API Gateway -> API Lambdas.
# ============================================================================

AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  jedx-collector

  Sample SAM Template for jedx-collector

# Globals:
#   # Default Lambda settings: 3s timeout; JSON log format for consistent observability.
Globals:
  Function:
    Timeout: 3
    LoggingConfig:
      LogFormat: JSON

# Parameters:
#   # Prefix: namespaces resource names per environment.
#   # CollectorUrl: external collector endpoint (useful if your code forwards outbound).
Parameters:
  Prefix:
    Type: String
    Default: jedx
    Description: Prefix for all resource names
  CollectorUrl:
    Type: String
    Default: 'https://jys7l8tndd.execute-api.us-east-1.amazonaws.com/Prod'
    Description: The URL for the collector API

Resources:
# ApplicationResourceGroup:
#   # Resource group to bundle all stack resources for discovery/monitoring.
  ApplicationResourceGroup:
    Type: AWS::ResourceGroups::Group
    Properties:
      Name: !Sub '${Prefix}-car-resource-group'
      ResourceQuery:
        Type: CLOUDFORMATION_STACK_1_0
# ApplicationInsightsMonitoring:
#   # Enables CloudWatch Application Insights on the resource group.
  ApplicationInsightsMonitoring:
    Type: AWS::ApplicationInsights::Application
    Properties:
      ResourceGroupName: !Sub '${Prefix}-car-resource-group'
      AutoConfigurationEnabled: 'true' 
#
# CAR Service Components
#    The following resources are part of the jedx-car service.
#      
# JedxCarInputBucket:
#   # Landing bucket for incoming files; versioned; triggers S3ToKinesisFunction on object create.
  JedxCarInputBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Prefix}-car-input-bucket'
      VersioningConfiguration:
        Status: Enabled
  
# JedxCarBucket:
#   # Primary bucket for validated/processed artifacts; versioned.
  JedxCarBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Prefix}-car-bucket'
      VersioningConfiguration:
        Status: Enabled

# JedxCarErrorBucket:
#   # Error bucket for invalid/failed payloads; versioned.
  JedxCarErrorBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Prefix}-car-error-bucket'
      VersioningConfiguration:
        Status: Enabled

# JedxCarInputStream:
#   # Kinesis stream used to drive validation from S3-originated events.
  JedxCarInputStream:
    Type: AWS::Kinesis::Stream
    Properties:
      Name: !Sub '${Prefix}-CarInputStream'
      ShardCount: 1

# JedxCarApi:
#   # API Gateway exposing /car endpoints; Cognito authorizer configured; CORS enabled.
  JedxCarApi:
    Type: AWS::Serverless::Api
    Properties:
      Name: !Sub '${Prefix}-car-api'
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
# JedxCarApiFunction:
#   # ANY /car handler; can enqueue to Kinesis and access DynamoDB.
  JedxCarApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-api-function'
      CodeUri: src/
      Handler: car_api/app.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCar:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCarApi
            Path: /car
            Method: ANY
      Environment:
        Variables:
          KINESIS_STREAM_NAME: !Ref JedxCarInputStream
          DDB_TABLE_NAME: !Ref JedxCarTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - kinesis:PutRecord
              Resource: !GetAtt JedxCarInputStream.Arn
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:Query
              Resource: !GetAtt JedxCarTable.Arn

# JedxCarRecordApiFunction:
#   # /car/record/{senderId}/{object_type}/{RefId}; interacts with S3 and DynamoDB.
  JedxCarRecordApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-record-api-function'
      CodeUri: src/
      Handler: car_api/record.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCar:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCarApi
            Path: /car/record/{senderId}/{object_type}/{RefId}
            Method: ANY
      Environment:
        Variables:
          S3_CAR_BUCKET: !Ref JedxCarBucket
          DDB_TABLE_NAME: !Ref JedxCarTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
                - s3:GetObjectVersion
                - s3:ListBucket
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Sub '${Prefix}-car-bucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCarTable.Arn
  
# JedxCarRecordsApiFunction:
#   # /car/records/{senderId}; list/query multiple records; uses S3 + DynamoDB.
  JedxCarRecordsApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-records-api-function'
      CodeUri: src/
      Handler: car_api/record.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCar:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCarApi
            Path: /car/records/{senderId}
            Method: ANY
      Environment:
        Variables:
          S3_CAR_BUCKET: !Ref JedxCarBucket
          DDB_TABLE_NAME: !Ref JedxCarTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
                - s3:ListBucket
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Sub '${Prefix}-car-bucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCarTable.Arn

# JedxCarCollectorSendApiFunction:
#   # /car/collector/send; forwards to external collector. Consider parameterizing COLLECTOR_URL.
  JedxCarCollectorSendApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-collector-send-api-function'
      CodeUri: src/
      Handler: car_api/collector.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCar:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCarApi
            Path: /car/collector/send
            Method: ANY
      Environment:
        Variables:
          S3_CAR_BUCKET: !Ref JedxCarBucket
          DDB_TABLE_NAME: !Ref JedxCarTable
          COLLECTOR_URL: 'https://jys7l8tndd.execute-api.us-east-1.amazonaws.com/Prod'          
          #COLLECTOR_URL: 'https://2l9isbfjdi.execute-api.us-east-1.amazonaws.com/Prod'
          
          #COLLECTOR_URL: !Ref CollectorUrl
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
                - s3:ListBucket
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Sub '${Prefix}-car-bucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCarTable.Arn

# JedxCarUserApiFunction:
#   # POST /car/login; user/auth flows using DynamoDB.
  JedxCarUserApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-user-api-function'
      CodeUri: src/
      Handler: car_api/user.lambda_handler
      Runtime: python3.11
      Architectures:
      - x86_64
      Events:
        JedxCar:
          Type: Api
          Properties:
            RestApiId: !Ref JedxCarApi
            Path: /car/login
            Method: POST
      Environment:
        Variables:
          DDB_TABLE_NAME: !Ref JedxCarTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - dynamodb:PutItem
                - dynamodb:UpdateItem
                - dynamodb:GetItem
                - dynamodb:Query
              Resource: !GetAtt JedxCarTable.Arn

# S3ToKinesisFunction:
#   # Triggered by JedxCarInputBucket object creation; publishes to Kinesis stream.
  S3ToKinesisFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-s3-to-kinesis-function'
      CodeUri: src/
      Handler: s3_to_kinesis_lambda/app.lambda_handler
      Runtime: python3.11
      Architectures:
        - x86_64
      Events:
        S3PutEvent:
          Type: S3
          Properties:
            Bucket: !Ref JedxCarInputBucket
            Events: s3:ObjectCreated:*
      Environment:
        Variables:
          KINESIS_STREAM_NAME: !Ref JedxCarInputStream
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - kinesis:PutRecord
              Resource: !GetAtt JedxCarInputStream.Arn
            - Effect: Allow
              Action:
                - s3:GetObject
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Sub '${Prefix}-car-input-bucket', '/*']]
# CarValidationFunction:
#   # Consumes Kinesis; validates records; writes success to main bucket, errors to error bucket, and metadata to DynamoDB.
  CarValidationFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Prefix}-car-validation-function'
      CodeUri: src/
      Handler: car_validation_lambda/app.lambda_handler
      Runtime: python3.11
      Architectures:
        - x86_64
      EventInvokeConfig: # Configuration for asynchronous invocations
          MaximumRetryAttempts: 0
      Events:
        KinesisEvent:
          Type: Kinesis
          Properties:
            Stream: !GetAtt JedxCarInputStream.Arn
            StartingPosition: LATEST
            BatchSize: 10
      Environment:
        Variables:
          S3_CAR_BUCKET: !Ref JedxCarBucket
          S3_CAR_ERROR_BUCKET: !Ref JedxCarErrorBucket
          DDB_TABLE_NAME: !Ref JedxCarTable
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - s3:PutObject
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Ref 'JedxCarBucket', '/*']]
            - Effect: Allow
              Action:
                - s3:PutObject
              Resource: 
                - !Join ['', ['arn:aws:s3:::', !Ref 'JedxCarErrorBucket', '/*']]
            - Effect: Allow
              Action:
                - dynamodb:PutItem
              Resource: !GetAtt JedxCarTable.Arn
# JedxCarTable:
#   # DynamoDB (pk/sk) table for metadata/state; PAY_PER_REQUEST billing.
  JedxCarTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${Prefix}-car-table'
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
#   # Exposes ARNs for ease of integration and permission management.
Outputs:
  JedxCollectorFunction:
    Description: Jedx Car Lambda Function ARN
    Value: !GetAtt JedxCarApiFunction.Arn
  JedxCollectorFunctionIamRole:
    Description: Implicit IAM Role created for Jedx Car function
    Value: !GetAtt JedxCarApiFunctionRole.Arn

```
