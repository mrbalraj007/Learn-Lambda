# How to Use the Architecture Diagram

## Opening the Diagram

1. You can open the architecture diagram by:
   - Using the online [draw.io](https://app.diagrams.net/) website
   - Using the draw.io desktop application (available for Windows, Mac, and Linux)
   - Using VS Code with the draw.io extension

2. To open the diagram:
   - Select "Open Existing Diagram" 
   - Browse for the `ebs-tagging-architecture.drawio` file

## Understanding the Architecture

The architecture diagram illustrates the following workflow:

1. **Triggers (Top of diagram)**
   - Orange flow: Daily scheduled trigger at 1 PM UTC
   - Green flow: Event-based trigger when volumes are attached/detached

2. **Lambda Function (Center)**
   - The core component that processes EBS volumes
   - Receives permissions from IAM role (yellow arrow)
   - Code deployed from S3 bucket (purple dashed-dot arrow)

3. **Resource Processing (Right side)**
   - Lambda reads EC2 instance tags (blue arrow to EC2)
   - Lambda applies tags to EBS volumes (blue arrow to EBS)
   - EC2 API calls (attach/detach) trigger EventBridge events

4. **Supporting Resources (Left and bottom)**
   - CloudWatch for logging Lambda execution (blue dashed arrow)
   - IAM role for permissions (yellow arrow)
   - S3 bucket for Lambda code storage (purple arrow)

## Color Coding

The diagram uses a consistent color scheme to represent different types of flows:

- **Orange arrows**: Scheduled event flow (daily trigger)
- **Green arrows**: Event-based flow (attach/detach events)
- **Blue arrows**: API calls and data flow
- **Purple arrows**: Code/deployment flow
- **Yellow arrows**: Permission/role assignment

## Editing the Diagram

Feel free to modify the diagram to reflect any changes in the architecture. The base diagram already includes:

- All major components of the EBS tagging solution
- Color-coded flows to differentiate between trigger types
- A legend explaining the arrow colors and meanings
- Clear labels for all components and connections

As the solution evolves, you may want to add:
- Additional components or resources
- More detailed process flows
- Resource names specific to your environment
- Region boundaries if deploying across multiple regions
