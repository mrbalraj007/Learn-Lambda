# PowerShell Script for AWS Route 53 Detailed Records Export
# Author: Professional AWS DevOps Engineer
# Date: $(Get-Date -Format "yyyy-MM-dd")
# Version: 2.0

param(
    [string]$Region = "ap-southeast-2",
    [string]$OutputDir = "route53_exports"
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Color definitions for console output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
    White = "White"
}

function Write-StatusMessage {
    param([string]$Message, [string]$Type = "Info")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        "Info" { Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor $Colors.Blue }
        "Success" { Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor $Colors.Green }
        "Warning" { Write-Host "[$timestamp] [WARNING] $Message" -ForegroundColor $Colors.Yellow }
        "Error" { Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor $Colors.Red }
        "Processing" { Write-Host "[$timestamp] [PROCESSING] $Message" -ForegroundColor $Colors.Cyan }
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "  AWS Route 53 Comprehensive Records Export Tool (PowerShell Edition)" -ForegroundColor Cyan
    Write-Host "  Professional AWS DevOps Engineer Script" -ForegroundColor Cyan
    Write-Host "  Region: $Region" -ForegroundColor Cyan
    Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-AwsCli {
    Write-StatusMessage "Checking AWS CLI installation and configuration..." "Info"
    
    # Check if AWS CLI is installed
    try {
        $null = Get-Command aws -ErrorAction Stop
    }
    catch {
        Write-StatusMessage "AWS CLI is not installed. Please install AWS CLI first." "Error"
        Write-StatusMessage "Installation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" "Error"
        exit 1
    }
    
    # Check if AWS CLI is configured
    try {
        $identity = aws sts get-caller-identity --query 'Arn' --output text 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "AWS CLI not configured"
        }
        Write-StatusMessage "AWS CLI configured - Identity: $identity" "Success"
    }
    catch {
        Write-StatusMessage "AWS CLI is not configured or credentials are invalid." "Error"
        Write-StatusMessage "Please run 'aws configure' to set up your credentials." "Error"
        exit 1
    }
}

function Test-Route53Permissions {
    Write-StatusMessage "Validating Route 53 permissions..." "Info"
    
    try {
        $null = aws route53 list-hosted-zones --max-items 1 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Permission denied"
        }
        Write-StatusMessage "Route 53 permissions validated" "Success"
    }
    catch {
        Write-StatusMessage "Insufficient permissions to access Route 53." "Error"
        Write-StatusMessage "Required permissions: route53:ListHostedZones, route53:GetHostedZone, route53:ListResourceRecordSets" "Error"
        exit 1
    }
}

function New-OutputDirectory {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-StatusMessage "Created output directory: $OutputDir" "Info"
    }
}

function New-CsvFileName {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return "$OutputDir\route53_detailed_records_$timestamp.csv"
}

function Add-CsvHeader {
    param([string]$FilePath)
    
    $header = @(
        "Hosted Zone Name",
        "Hosted Zone ID",
        "Zone Type",
        "Record Name",
        "Record Type",
        "Routing Policy",
        "Alias Target",
        "Alias Hosted Zone ID",
        "Value/Route Traffic To",
        "TTL",
        "Evaluate Target Health",
        "Set Identifier",
        "Weight",
        "Region",
        "Failover",
        "Health Check ID",
        "Export Timestamp"
    )
    
    $header -join "," | Out-File -FilePath $FilePath -Encoding UTF8
    Write-StatusMessage "CSV header written to $FilePath" "Info"
}

function Get-ZoneType {
    param([string]$ZoneId)
    
    try {
        $vpcInfo = aws route53 get-hosted-zone --id $ZoneId --query 'VPCs' --output text 2>$null
        if ($vpcInfo -eq "None" -or [string]::IsNullOrEmpty($vpcInfo) -or $vpcInfo -eq "null") {
            return "Public"
        }
        else {
            return "Private"
        }
    }
    catch {
        return "Unknown"
    }
}

function Get-RoutingPolicy {
    param([PSCustomObject]$Record)
    
    if ($Record.Weight) { return "Weighted" }
    elseif ($Record.Region) { return "Latency-based" }
    elseif ($Record.Failover) { return "Failover" }
    elseif ($Record.SetIdentifier) { return "Geolocation/Geoproximity" }
    else { return "Simple" }
}

function Export-ZoneRecords {
    param(
        [string]$ZoneName,
        [string]$ZoneId,
        [string]$ZoneType,
        [string]$FilePath,
        [string]$ExportTime
    )
    
    Write-StatusMessage "Processing records for hosted zone: $ZoneName" "Processing"
    
    try {
        $recordsJson = aws route53 list-resource-record-sets --hosted-zone-id $ZoneId --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-StatusMessage "Failed to retrieve records for hosted zone: $ZoneName" "Warning"
            return
        }
        
        $records = $recordsJson | ConvertFrom-Json
        $recordCount = $records.ResourceRecordSets.Count
        Write-StatusMessage "Found $recordCount records in hosted zone: $ZoneName" "Info"
        
        foreach ($record in $records.ResourceRecordSets) {
            # Extract basic information
            $recordName = $record.Name -replace '\.$', ''
            $recordType = $record.Type
            $ttl = if ($record.TTL) { $record.TTL } else { "" }
            
            # Extract alias information
            $aliasTarget = ""
            $aliasZoneId = ""
            $evaluateTargetHealth = ""
            
            if ($record.AliasTarget) {
                $aliasTarget = if ($record.AliasTarget.DNSName) { $record.AliasTarget.DNSName } else { "" }
                $aliasZoneId = if ($record.AliasTarget.HostedZoneId) { $record.AliasTarget.HostedZoneId } else { "" }
                $evaluateTargetHealth = if ($record.AliasTarget.EvaluateTargetHealth) { $record.AliasTarget.EvaluateTargetHealth } else { "" }
            }
            
            # Extract resource records
            $values = ""
            if ($record.ResourceRecords) {
                $valuesList = $record.ResourceRecords | ForEach-Object { $_.Value }
                $values = $valuesList -join "; "
            }
            
            # Determine route traffic to
            $routeTrafficTo = if ($aliasTarget) { $aliasTarget } else { $values }
            
            # Extract routing policy information
            $routingPolicy = Get-RoutingPolicy -Record $record
            $setIdentifier = if ($record.SetIdentifier) { $record.SetIdentifier } else { "" }
            $weight = if ($record.Weight) { $record.Weight } else { "" }
            $region = if ($record.Region) { $record.Region } else { "" }
            $failover = if ($record.Failover) { $record.Failover } else { "" }
            $healthCheckId = if ($record.HealthCheckId) { $record.HealthCheckId } else { "" }
            
            # Create CSV row
            $csvRow = @(
                "`"$ZoneName`"",
                "`"$ZoneId`"",
                "`"$ZoneType`"",
                "`"$recordName`"",
                "`"$recordType`"",
                "`"$routingPolicy`"",
                "`"$aliasTarget`"",
                "`"$aliasZoneId`"",
                "`"$routeTrafficTo`"",
                "`"$ttl`"",
                "`"$evaluateTargetHealth`"",
                "`"$setIdentifier`"",
                "`"$weight`"",
                "`"$region`"",
                "`"$failover`"",
                "`"$healthCheckId`"",
                "`"$ExportTime`""
            )
            
            $csvRow -join "," | Out-File -FilePath $FilePath -Append -Encoding UTF8
        }
        
        Write-StatusMessage "Completed processing hosted zone: $ZoneName" "Success"
    }
    catch {
        Write-StatusMessage "Error processing hosted zone $ZoneName`: $($_.Exception.Message)" "Error"
    }
}

function Export-Route53Info {
    param([string]$FilePath)
    
    $exportTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-StatusMessage "Starting Route 53 export process..." "Info"
    
    try {
        # Get all hosted zones
        Write-StatusMessage "Retrieving list of hosted zones..." "Info"
        $zonesJson = aws route53 list-hosted-zones --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve hosted zones list"
        }
        
        $zones = $zonesJson | ConvertFrom-Json
        $zoneCount = $zones.HostedZones.Count
        Write-StatusMessage "Found $zoneCount hosted zones to process" "Success"
        
        if ($zoneCount -eq 0) {
            Write-StatusMessage "No hosted zones found in the current AWS account" "Warning"
            return
        }
        
        # Process each hosted zone
        $currentZone = 1
        foreach ($zone in $zones.HostedZones) {
            $zoneName = $zone.Name -replace '\.$', ''
            $zoneId = $zone.Id -replace '/hostedzone/', ''
            $zoneType = Get-ZoneType -ZoneId $zoneId
            
            Write-Host ""
            Write-StatusMessage "Processing hosted zone $currentZone of $zoneCount`: $zoneName" "Info"
            
            Export-ZoneRecords -ZoneName $zoneName -ZoneId $zoneId -ZoneType $zoneType -FilePath $FilePath -ExportTime $exportTime
            
            $currentZone++
        }
    }
    catch {
        Write-StatusMessage "Error during export: $($_.Exception.Message)" "Error"
        exit 1
    }
}

function Show-ExportSummary {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        $totalRecords = (Get-Content $FilePath).Count - 1  # Subtract header line
        $fileSize = [math]::Round((Get-Item $FilePath).Length / 1KB, 2)
        
        Write-Host ""
        Write-StatusMessage "Export completed successfully!" "Success"
        Write-Host "==================================" -ForegroundColor Green
        Write-Host "Export Summary:" -ForegroundColor Green
        Write-Host "==================================" -ForegroundColor Green
        Write-Host "Output file: $FilePath" -ForegroundColor Green
        Write-Host "Total records exported: $totalRecords" -ForegroundColor Green
        Write-Host "File size: $fileSize KB" -ForegroundColor Green
        Write-Host "Export completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
        Write-Host "==================================" -ForegroundColor Green
        Write-Host ""
        Write-StatusMessage "You can open the CSV file in Excel, Google Sheets, or any CSV viewer" "Info"
    }
    else {
        Write-StatusMessage "Export file not found: $FilePath" "Error"
    }
}

# Main execution
function Main {
    # Show banner
    Show-Banner
    
    # Pre-flight checks
    Test-AwsCli
    Test-Route53Permissions
    New-OutputDirectory
    
    # Generate filename and create CSV
    $csvFile = New-CsvFileName
    Write-StatusMessage "Export will be saved to: $csvFile" "Info"
    
    # Write CSV header
    Add-CsvHeader -FilePath $csvFile
    
    # Export Route 53 information
    Export-Route53Info -FilePath $csvFile
    
    # Display summary
    Show-ExportSummary -FilePath $csvFile
    
    Write-StatusMessage "Route 53 detailed export process completed!" "Success"
}

# Execute main function
Main
