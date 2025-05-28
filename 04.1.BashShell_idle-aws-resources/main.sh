#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HTML_REPORT="aws_audit_report_${TIMESTAMP}.html"
exec > >(tee "${HTML_REPORT}") 2>&1

# Start HTML
echo "<!DOCTYPE html>"
echo "<html lang='en'>"
echo "<head>
  <meta charset='UTF-8'>
  <title>AWS Audit Report</title>
  <style>
    header {
        background: #2f80ed;
        color: white;
        padding: 40px 20px;
        text-align: center;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    header h1 {
        margin: 0;
        font-size: 36px;
    }
    .container {
        max-width: 960px;
        margin: 30px auto;
        padding: 0 20px;
    }
    .info {
        background: #ffffff;
        padding: 20px;
        border-radius: 10px;
        margin-bottom: 30px;
        box-shadow: 0 3px 10px rgba(0,0,0,0.05);
    }
    .section {
        background: #ffffff;
        border-left: 6px solid #2f80ed;
        border-radius: 10px;
        padding: 20px;
        margin: 20px 0;
        box-shadow: 0 3px 10px rgba(0,0,0,0.06);
    }
    .section h2 {
        margin-top: 0;
        color: #2c3e50;
        font-size: 20px;
        display: flex;
        align-items: center;
    }
    .section h2 span {
        font-size: 24px;
        margin-right: 10px;
    }
    pre {
        background: #f9fafc;
        padding: 15px;
        border-radius: 6px;
        overflow-x: auto;
        font-size: 14px;
        line-height: 1.5;
        border: 1px solid #e0e6ed;
    }
    .status-ok { color: #27ae60; font-weight: bold; }
    .status-warn { color: #e67e22; font-weight: bold; }
    .status-fail { color: #c0392b; font-weight: bold; }
    footer {
        text-align: center;
        font-size: 13px;
        padding: 30px 10px;
        color: #777;
    }
  </style>
</head>
<body>"

echo "<header><h1>📊 AWS Cost Audit Report</h1></header>"
echo "<div class='container'>"
echo "<div class='info'><p><strong>Date:</strong> $(date +'%d-%b-%Y %H:%M:%S')</p>"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
echo "<p><strong>AWS Account ID:</strong> $ACCOUNT_ID</p></div>"

run_check() {
    TITLE="$1"
    SCRIPT="$2"
    ICON="$3"
    echo "<div class='section'>"
    echo "<h2><span>$ICON</span> $TITLE</h2><pre>"
    if [ -f "$SCRIPT" ]; then
        bash "$SCRIPT"
    else
        echo "⚠️ Script not found: $SCRIPT"
    fi
    echo "</pre></div>"
}

ALL_REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text || echo "")

REGIONS_SCANNED=0
skip_all=false

for REGION in $ALL_REGIONS; do
    if [ "$skip_all" = false ]; then
        echo -n "🗺️  Scan region '$REGION'? (y/n, or 'a' to skip ALL remaining): "
        read -r REPLY < /dev/tty
        REPLY=${REPLY,,}  # lowercase

        if [[ "$REPLY" == "y" ]]; then
            :
        elif [[ "$REPLY" == "a" || "$REPLY" == "n" ]]; then
            skip_all=true
            if [[ "$REPLY" == "n" ]]; then
                echo "⏭️ Skipping region '$REGION'"
                continue
            fi
            echo "⏭️ Skipping all remaining regions."
            continue
        else
            echo "❌ Invalid input, assuming 'n'. Skipping region '$REGION'"
            skip_all=true
            continue
        fi
    else
        echo "⏭️ Skipping region '$REGION'"
        continue
    fi

    REGIONS_SCANNED=$((REGIONS_SCANNED + 1))
    aws configure set region "$REGION"
    echo "<div class='section'>"
    echo "<h2><span>🌍</span> Region: $REGION</h2>"

    run_check "💰 Budget Alerts Check" "./check_budgets.sh" "💰"
    run_check "🏷️ Untagged Resources Check" "./check_untagged_resources.sh" "🏷️"
    run_check "🛌 Idle EC2 Resources Check" "./check_idle_ec2.sh" "🛌"
    run_check "♻️ S3 Lifecycle Policies Check" "./check_s3_lifecycle.sh" "♻️"
    run_check "📅 Old RDS Snapshots Check" "./check_old_rds_snapshots.sh" "📅"
    run_check "🧹 Forgotten EBS Volumes Check" "./check_forgotten_ebs.sh" "🧹"
    run_check "🌐 Data Transfer Risks Check" "./check_data_transfer_risks.sh" "🌐"
    run_check "💸 On-Demand EC2 Instances Check" "./check_on_demand_instances.sh" "💸"
    run_check "🛑 Idle Load Balancers Check" "./check_idle_load_balancers.sh" "🛑"
    run_check "🌍 Route 53 Records Check" "./check_route53.sh" "🌍"
    run_check "☸️ EKS Clusters Check" "./check_eks_clusters.sh" "☸️"
    run_check "🔐 IAM Usage Check" "./check_iam_usage.sh" "🔐"
    run_check "🛡️ Security Groups Check" "./check_security_groups.sh" "🛡️"

    echo "<h3 class='status-ok'>✅ AWS Audit Completed for region: $REGION</h3>"
    echo "</div>"
done

if [ $REGIONS_SCANNED -eq 0 ]; then
    echo "<div class='section'><h2 class='status-warn'>⚠️ No regions selected for scanning.</h2></div>"
fi

echo "<h2 class='status-ok'>✅ AWS Audit Completed</h2>"
echo "</div>"
echo "</body></html>"

echo "✅ HTML report saved to: $HTML_REPORT"
