#!/bin/bash

echo "Fetching SSM Agent status for all managed instances..."

aws ssm describe-instance-information \
    --query "InstanceInformationList[*].{InstanceId:InstanceId, AgentVersion:AgentVersion, PingStatus:PingStatus, LastPingDateTime:LastPingDateTime, PlatformType:PlatformType, PlatformName:PlatformName, PlatformVersion:PlatformVersion}" \
    --output table

echo ""
echo "SSM Agent Status Report Completed."
