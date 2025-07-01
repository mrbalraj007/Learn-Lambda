#!/bin/bash

#==============================================================================
# Script Name: validate_permissions.sh
# Description: Validate AWS permissions for Route 53 operations
# Author: AWS DevOps Engineer
# Date: $(date +"%Y-%m-%d")
# Version: 1.0
#==============================================================================

# Set default AWS region
export AWS_DEFAULT_REGION="ap-southeast-2"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Function to test AWS permissions
test_permissions() {
    local failed_tests=0
    
    echo "==================================================================="
    echo "              AWS Route 53 Permission Validator"
    echo "==================================================================="
    echo "Region: $AWS_DEFAULT_REGION"
    echo "Testing AWS permissions required for Route 53 export..."
    echo "==================================================================="
    echo
    
    # Test 1: Check if user can list hosted zones
    print_status "Testing route53:ListHostedZones permission..."
    if aws route53 list-hosted-zones --max-items 1 >/dev/null 2>&1; then
        print_success "✓ route53:ListHostedZones - PASSED"
    else
        print_error "✗ route53:ListHostedZones - FAILED"
        failed_tests=$((failed_tests + 1))
    fi
    
    # Test 2: Check if user can get hosted zone details
    print_status "Testing route53:GetHostedZone permission..."
    # First get a hosted zone ID to test with
    zone_id=$(aws route53 list-hosted-zones --max-items 1 --query 'HostedZones[0].Id' --output text 2>/dev/null)
    
    if [ "$zone_id" != "None" ] && [ -n "$zone_id" ]; then
        if aws route53 get-hosted-zone --id "$zone_id" >/dev/null 2>&1; then
            print_success "✓ route53:GetHostedZone - PASSED"
        else
            print_error "✗ route53:GetHostedZone - FAILED"
            failed_tests=$((failed_tests + 1))
        fi
    else
        print_warning "⚠ route53:GetHostedZone - SKIPPED (No hosted zones found to test)"
    fi
    
    # Test 3: Check if user can list resource record sets
    print_status "Testing route53:ListResourceRecordSets permission..."
    if [ "$zone_id" != "None" ] && [ -n "$zone_id" ]; then
        if aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --max-items 1 >/dev/null 2>&1; then
            print_success "✓ route53:ListResourceRecordSets - PASSED"
        else
            print_error "✗ route53:ListResourceRecordSets - FAILED"
            failed_tests=$((failed_tests + 1))
        fi
    else
        print_warning "⚠ route53:ListResourceRecordSets - SKIPPED (No hosted zones found to test)"
    fi
    
    # Test 4: Check STS permissions (for caller identity)
    print_status "Testing sts:GetCallerIdentity permission..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_success "✓ sts:GetCallerIdentity - PASSED"
    else
        print_error "✗ sts:GetCallerIdentity - FAILED"
        failed_tests=$((failed_tests + 1))
    fi
    
    echo
    echo "==================================================================="
    
    # Display results
    if [ $failed_tests -eq 0 ]; then
        print_success "All permission tests passed! ✓"
        echo
        print_status "You can now run the Route 53 export script:"
        echo "  ./export_route53_info.sh"
        echo
        
        # Display current AWS identity
        print_status "Current AWS Identity:"
        aws sts get-caller-identity --query '{UserId:UserId,Account:Account,Arn:Arn}' --output table
        
        return 0
    else
        print_error "Permission validation failed! ✗"
        echo
        print_error "$failed_tests test(s) failed. Please ensure your AWS user/role has the required permissions."
        echo
        echo "Required IAM permissions:"
        echo "  - route53:ListHostedZones"
        echo "  - route53:GetHostedZone"
        echo "  - route53:ListResourceRecordSets"
        echo "  - sts:GetCallerIdentity"
        echo
        return 1
    fi
}

# Main execution
main() {
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Run permission tests
    test_permissions
    exit_code=$?
    
    echo "==================================================================="
    echo "Validation completed at: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "==================================================================="
    
    exit $exit_code
}

# Execute main function
main "$@"
