# Architecture Diagram Instructions

## Component Placement

1. **Place EC2 instances** on the left side
   - Use the EC2 icon
   - Add 2-3 instances with different states (running, stopped, terminated)
   - Color: Use AWS orange (#FF9900) for the border

2. **Add CloudWatch Events** in the center-left
   - Use CloudWatch icon
   - Color: Use AWS blue (#232F3E) with light blue (#1A73E8) border
   - Add text "Detects state changes"

3. **Add CloudTrail** in the top center
   - Use CloudTrail icon
   - Color: Use default AWS colors with light gray background
   - Add text "Logs API activity"

4. **Add Lambda Function** in the center
   - Use Lambda icon
   - Color: Use AWS orange (#FF9900) for the border and light orange (#FDF2E9) for background
   - Label it "EC2StateMonitor"

5. **Add IAM Role** connected to Lambda
   - Use IAM icon
   - Color: Use red (#D13212) for emphasis
   - Label it "EC2StateMonitorRole"

6. **Add SNS Topic** to the right of Lambda
   - Use SNS icon
   - Color: Use purple (#4D27AA) for border
   - Label it "EC2StateChangeTopic"

7. **Add Email Recipient** on far right
   - Use User or Email icon
   - Color: Use green (#007F5F) to indicate successful notification
   - Label it "Admin Email"

## Connect Components with Arrows

1. EC2 instances → CloudWatch (label: "State changes")
2. CloudWatch → Lambda (label: "Triggers function")
3. Lambda → CloudTrail (label: "Queries for initiator")
4. CloudTrail → Lambda (label: "Returns action history")
5. Lambda → SNS (label: "Sends notification")
6. SNS → Email (label: "Delivers email alert")
7. IAM Role → Lambda (label: "Provides permissions")

## Add a Title and Legend

1. Add title "EC2 Instance State Monitoring Architecture" at the top
   - Use large font, bold, AWS blue color (#232F3E)

2. Add a legend explaining color scheme:
   - Triggers/Events: Blue
   - Processing: Orange
   - Notification: Purple
   - Permissions: Red
   - Recipient: Green

## Final Touches

1. Add a light gradient background to the entire diagram
   - Light gray (#F2F3F3) to white

2. Group related elements together
   - Group EC2 and CloudWatch as "Monitoring Layer"
   - Group Lambda and CloudTrail as "Processing Layer" 
   - Group SNS and Email as "Notification Layer"

3. Add a brief description at the bottom
   - "This architecture monitors EC2 instance state changes and notifies administrators via email with details including who initiated the change."
