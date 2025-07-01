#!/bin/bash

#==============================================================================
# Script Name: validate_route53_permissions.sh
# Description: Validate AWS permissions for Route 53 detailed export
# Author: Professional AWS DevOps Engineer
# Date: $(date +"%Y-%m-%d")
# Version: 1.0
#==============================================================================

# Set default AWS region
export AWS_DEFAULT_REGION="ap-southeast-2"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# Function to display validation banner
display_banner() {
    echo -e "${CYAN}"
    echo "=============================================================================="
    echo "  AWS Route 53 Permissions Validation Tool"
    echo "  Professional AWS DevOps Engineer Script"
    echo "  Region: $AWS_DEFAULT_REGION"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================================================="
    echo -e "${NC}"
}

# Function to check if AWS CLI is installed
check_aws_cli_installation() {
    print_test "Checking AWS CLI installation..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        print_error "Install from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return 1
    fi
    
    local aws_version=$(aws --version 2>&1)
    print_success "AWS CLI installed: $aws_version"
    return 0
}

# Function to check AWS credentials
check_aws_credentials() {
    print_test "Checking AWS credentials configuration..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        print_error "Run 'aws configure' to set up credentials"
        return 1
    fi
    
    local identity=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    local account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    print_success "AWS credentials configured"
    print_status "Identity: $identity"
    print_status "Account: $account"
    return 0
}

# Function to test specific AWS permission
test_permission() {
    local action=$1
    local description=$2
    local test_command=$3
    
    print_test "Testing permission: $action"
    print_status "Description: $description"
    
    if eval "$test_command" &> /dev/null; then
        print_success "✓ $action - PASSED"
        return 0
    else
        print_error "✗ $action - FAILED"
        return 1
    fi
}

# Main validation function
validate_permissions() {
    local failed_tests=0
    
    print_status "Starting Route 53 permissions validation..."
    echo ""
    
    # Test 1: sts:GetCallerIdentity
    if ! test_permission "sts:GetCallerIdentity" "Verify AWS identity" "aws sts get-caller-identity"; then
        ((failed_tests++))
    fi
    echo ""
    
    # Test 2: route53:ListHostedZones
    if ! test_permission "route53:ListHostedZones" "List all hosted zones" "aws route53 list-hosted-zones --max-items 1"; then
        ((failed_tests++))
    fi
    echo ""
    
    # Test 3: route53:GetHostedZone
    print_test "Testing permission: route53:GetHostedZone"
    print_status "Description: Get hosted zone details"
    
    # Get first hosted zone ID for testing
    local first_zone_id=$(aws route53 list-hosted-zones --max-items 1 --query 'HostedZones[0].Id' --output text 2>/dev/null | sed 's|/hostedzone/||g')
    
    if [ "$first_zone_id" != "None" ] && [ -n "$first_zone_id" ] && [ "$first_zone_id" != "null" ]; then
        if aws route53 get-hosted-zone --id "$first_zone_id" &> /dev/null; then
            print_success "✓ route53:GetHostedZone - PASSED"
        else
            print_error "✗ route53:GetHostedZone - FAILED"
            ((failed_tests++))
        fi
    else
        print_warning "✓ route53:GetHostedZone - SKIPPED (No hosted zones found)"
    fi
    echo ""
    
    # Test 4: route53:ListResourceRecordSets
    print_test "Testing permission: route53:ListResourceRecordSets"
    print_status "Description: List DNS records in hosted zones"
    
    if [ "$first_zone_id" != "None" ] && [ -n "$first_zone_id" ] && [ "$first_zone_id" != "null" ]; then
        if aws route53 list-resource-record-sets --hosted-zone-id "$first_zone_id" --max-items 1 &> /dev/null; then
            print_success "✓ route53:ListResourceRecordSets - PASSED"
        else
            print_error "✗ route53:ListResourceRecordSets - FAILED"
            ((failed_tests++))
        fi
    else
        print_warning "✓ route53:ListResourceRecordSets - SKIPPED (No hosted zones found)"
    fi
    echo ""
    
    # Test 5: route53:ListHealthChecks (Optional)
    if ! test_permission "route53:ListHealthChecks" "List health checks (optional)" "aws route53 list-health-checks --max-items 1"; then
        print_warning "Health checks permission missing - this is optional"
    fi
    echo ""
    
    # Summary
    echo -e "${CYAN}=============================================================================="
    echo "  VALIDATION SUMMARY"
    echo -e "==============================================================================${NC}"
    
    if [ $failed_tests -eq 0 ]; then
        print_success "All required permissions are working correctly!"
        print_success "You can now run the Route 53 export scripts successfully."
        echo ""
        print_status "Next steps:"
        print_status "1. Run: ./export_route53_records_detailed.sh (Linux/macOS/WSL)"
        print_status "2. Or run: .\\Export-Route53RecordsDetailed.ps1 (Windows PowerShell)"
        print_status "3. Or run: run_route53_detailed_export.bat (Windows)"
        return 0
    else
        print_error "Validation failed! $failed_tests permission test(s) failed."
        echo ""
        print_error "Required IAM permissions (add to your user/role):"
        echo ""
        cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets",
        "route53:GetHealthCheck",
        "route53:ListHealthChecks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF
        echo ""
        print_error "Please add these permissions and run the validation again."
        return 1
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=0
    
    print_status "Checking script dependencies..."
    
    # Check for jq (required for bash script)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed (required for bash script)"
        print_status "Install: sudo apt-get install jq (Ubuntu/Debian)"
        print_status "Install: sudo yum install jq (CentOS/RHEL)"
        print_status "Install: brew install jq (macOS)"
        ((missing_deps++))
    else
        print_success "jq is installed"
    fi
    
    return $missing_deps
}

# Main execution function
main() {
    display_banner
    
    local exit_code=0
    
    # Check AWS CLI installation
    if ! check_aws_cli_installation; then
        exit_code=1
    fi
    echo ""
    
    # Check dependencies
    check_dependencies
    echo ""
    
    # Check AWS credentials
    if ! check_aws_credentials; then
        exit_code=1
    fi
    echo ""
    
    # Validate permissions (only if credentials are working)
    if [ $exit_code -eq 0 ]; then
        if ! validate_permissions; then
            exit_code=1
        fi
    else
        print_error "Skipping permission validation due to credential issues"
    fi
    
    exit $exit_code
}

# Script execution starts here
main "$@"
