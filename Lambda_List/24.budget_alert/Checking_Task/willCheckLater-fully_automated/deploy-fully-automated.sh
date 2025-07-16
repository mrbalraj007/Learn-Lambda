#!/bin/bash

# Fully automated deployment script
# No manual intervention required

echo "Deploying fully automated budget restriction solution..."

# Check if stack already exists
STACK_EXISTS=$(aws cloudformation describe-stacks \
  --stack-name FullyAutomatedBudgetRestriction \
  --region us-east-1 \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null)

if [ "$STACK_EXISTS" != "" ]; then
    echo "Stack already exists with status: $STACK_EXISTS"
    echo "Deleting existing stack first..."
    aws cloudformation delete-stack \
      --stack-name FullyAutomatedBudgetRestriction \
      --region us-east-1
    
    echo "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete \
      --stack-name FullyAutomatedBudgetRestriction \
      --region us-east-1
    
    if [ $? -eq 0 ]; then
        echo "Stack deleted successfully"
    else
        echo "Stack deletion failed or timed out"
        exit 1
    fi
fi

# Deploy the comprehensive CloudFormation template
echo "Creating new stack..."
aws cloudformation create-stack \
  --stack-name FullyAutomatedBudgetRestriction \
  --template-body file://fully-automated-budget-restriction.yaml \
  --parameters ParameterKey=EmailAddress,ParameterValue=raj10ace@gmail.com \
              ParameterKey=BudgetLimit,ParameterValue=100 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

if [ $? -eq 0 ]; then
    echo "Stack deployment initiated successfully!"
    echo "Monitor the stack creation progress in the CloudFormation console"
    echo "Stack name: FullyAutomatedBudgetRestriction"
    
    # Wait for stack creation to complete
    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
      --stack-name FullyAutomatedBudgetRestriction \
      --region us-east-1
    
    if [ $? -eq 0 ]; then
        echo "Stack created successfully!"
        echo "Retrieving stack outputs..."
        aws cloudformation describe-stacks \
          --stack-name FullyAutomatedBudgetRestriction \
          --query "Stacks[0].Outputs" \
          --output table \
          --region us-east-1
    else
        echo "Stack creation failed or timed out"
        echo "Checking for failed events..."
        aws cloudformation describe-stack-events \
          --stack-name FullyAutomatedBudgetRestriction \
          --region us-east-1 \
          --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].{Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}" \
          --output table
        
        echo "Checking Lambda function logs..."
        LOG_GROUP="/aws/lambda/BudgetActionCreatorFunction"
        
        # Check if log group exists
        if aws logs describe-log-groups \
          --log-group-name-prefix "$LOG_GROUP" \
          --region us-east-1 \
          --query "logGroups[0].logGroupName" \
          --output text 2>/dev/null | grep -q "BudgetActionCreatorFunction"; then
            
            echo "Found Lambda log group, retrieving latest logs..."
            
            # Get the latest log stream
            LATEST_STREAM=$(aws logs describe-log-streams \
              --log-group-name "$LOG_GROUP" \
              --region us-east-1 \
              --order-by LastEventTime \
              --descending \
              --max-items 1 \
              --query "logStreams[0].logStreamName" \
              --output text 2>/dev/null)
            
            if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "" ]; then
                echo "Latest log stream: $LATEST_STREAM"
                echo "Lambda function logs:"
                echo "===================="
                aws logs get-log-events \
                  --log-group-name "$LOG_GROUP" \
                  --log-stream-name "$LATEST_STREAM" \
                  --region us-east-1 \
                  --query "events[*].message" \
                  --output text
                echo "===================="
            else
                echo "No log streams found in Lambda log group"
            fi
        else
            echo "Lambda log group not found yet"
        fi
        
        # Also check CloudFormation stack events for more details
        echo ""
        echo "Detailed CloudFormation events:"
        echo "==============================="
        aws cloudformation describe-stack-events \
          --stack-name FullyAutomatedBudgetRestriction \
          --region us-east-1 \
          --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[Timestamp,LogicalResourceId,ResourceStatusReason]" \
          --output table
        
        exit 1
    fi
else
    echo "Failed to initiate stack deployment"
    exit 1
fi

echo ""
echo "Deployment complete! Your budget restriction is now fully automated."
echo "No further manual steps required."
