#!/bin/bash

#==============================================================================
# Script Name: setup.sh
# Description: Setup script to make all scripts executable
# Author: AWS DevOps Engineer
# Version: 1.0
#==============================================================================

echo "==================================================================="
echo "              AWS Route 53 Export Tool Setup"
echo "==================================================================="
echo

# Make bash scripts executable
echo "[INFO] Making bash scripts executable..."
chmod +x export_route53_info.sh
chmod +x validate_permissions.sh
chmod +x setup.sh

# Check if files were made executable
if [ -x "export_route53_info.sh" ] && [ -x "validate_permissions.sh" ]; then
    echo "[SUCCESS] Scripts are now executable!"
else
    echo "[ERROR] Failed to make scripts executable"
    exit 1
fi

echo
echo "Setup completed! You can now use the following commands:"
echo
echo "1. Validate AWS permissions:"
echo "   ./validate_permissions.sh"
echo
echo "2. Export Route 53 information:"
echo "   ./export_route53_info.sh"
echo
echo "For Windows users:"
echo "3. Use PowerShell script:"
echo "   .\Export-Route53Info.ps1"
echo
echo "4. Use batch file (requires WSL):"
echo "   run_route53_export.bat"
echo
echo "==================================================================="
