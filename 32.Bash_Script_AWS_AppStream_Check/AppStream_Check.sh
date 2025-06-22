#!/bin/bash

echo "Fetching list of active AWS regions..."
regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

for region in $regions; do
    echo -e "\n🔎 Region: $region"
    
    echo "📌 Checking AppStream Fleets..."
    aws appstream describe-fleets --region "$region" --query "Fleets[?State!='STOPPED'].{Name:Name,State:State}" --output table

    echo "📌 Checking AppStream Stacks..."
    aws appstream describe-stacks --region "$region" --output table

    echo "📌 Checking WorkSpaces..."
    aws workspaces describe-workspaces --region "$region" --query "Workspaces[].[WorkspaceId,State,UserName]" --output table

    echo "📌 Checking Directory Services..."
    aws ds describe-directories --region "$region" --query "DirectoryDescriptions[].[DirectoryId,Name,Type,Stage]" --output table
done
