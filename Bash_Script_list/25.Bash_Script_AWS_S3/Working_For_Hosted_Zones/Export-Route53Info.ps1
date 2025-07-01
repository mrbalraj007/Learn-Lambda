# ==============================================================================
# Script Name: Export-Route53Info.ps1
# Description: PowerShell script to export Route 53 information to CSV
# Author: AWS DevOps Engineer
# Date: 2025-07-01
# Version: 1.0
# ==============================================================================

param(
    [string]$Region = "ap-southeast-2",
    [string]$OutputPath = "route53_exports"
)

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

# Function to check AWS CLI
function Test-AwsCli {
    Write-Info "Checking AWS CLI installation and configuration..."
    
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    }
    
    try {
        aws sts get-caller-identity | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "AWS CLI configuration error"
        }
        Write-Success "AWS CLI is properly configured"
    }
    catch {
        Write-Error "AWS CLI is not configured or credentials are invalid."
        Write-Error "Please run 'aws configure' to set up your credentials."
        exit 1
    }
}

# Function to create output directory
function New-OutputDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Info "Created output directory: $Path"
    }
}

# Function to generate CSV filename
function Get-CsvFileName {
    param([string]$BasePath)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return Join-Path $BasePath "route53_hosted_zones_$timestamp.csv"
}

# Function to get hosted zone type
function Get-ZoneType {
    param([string]$ZoneId)
    
    try {
        $result = aws route53 get-hosted-zone --id $ZoneId --query 'VPCs' --output text
        if ($result -eq "None" -or [string]::IsNullOrEmpty($result)) {
            return "Public"
        } else {
            return "Private"
        }
    }
    catch {
        return "Unknown"
    }
}

# Function to get record count
function Get-RecordCount {
    param([string]$ZoneId)
    
    try {
        $count = aws route53 list-resource-record-sets --hosted-zone-id $ZoneId --query 'length(ResourceRecordSets)' --output text
        if ([string]::IsNullOrEmpty($count) -or $count -eq "None") {
            return 0
        }
        return [int]$count
    }
    catch {
        return 0
    }
}

# Function to clean CSV data
function Format-CsvData {
    param([string]$Data)
    
    if ([string]::IsNullOrEmpty($Data) -or $Data -eq "None") {
        return "N/A"
    }
    
    # Escape quotes and remove newlines
    return $Data.Replace('"', '""').Replace("`n", " ").Replace("`r", " ")
}

# Main export function
function Export-Route53Info {
    param([string]$CsvFile)
    
    Write-Info "Fetching Route 53 hosted zones information..."
    
    # Get all hosted zones
    try {
        $hostedZonesJson = aws route53 list-hosted-zones --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve hosted zones"
        }
        
        $hostedZones = $hostedZonesJson | ConvertFrom-Json
        $zoneCount = $hostedZones.HostedZones.Count
        
        Write-Info "Found $zoneCount hosted zone(s) to process"
        
        # Create CSV header
        $csvHeader = "Hosted Zone Name,Type,Created By,Record Count,Description,Hosted Zone ID,Export Date"
        $csvHeader | Out-File -FilePath $CsvFile -Encoding UTF8
        
        $processedCount = 0
        
        foreach ($zone in $hostedZones.HostedZones) {
            $processedCount++
            Write-Info "Processing zone $processedCount/$zoneCount`: $($zone.Name)"
            
            # Clean zone ID
            $cleanZoneId = $zone.Id -replace '/hostedzone/', ''
            
            # Get zone type
            $zoneType = Get-ZoneType -ZoneId $cleanZoneId
            
            # Get record count
            $recordCount = Get-RecordCount -ZoneId $cleanZoneId
            
            # Format data
            $zoneName = Format-CsvData -Data $zone.Name
            $callerRef = Format-CsvData -Data $zone.CallerReference
            $description = Format-CsvData -Data $zone.Config.Comment
            $exportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Create CSV row
            $csvRow = "`"$zoneName`",`"$zoneType`",`"$callerRef`",`"$recordCount`",`"$description`",`"$cleanZoneId`",`"$exportDate`""
            $csvRow | Out-File -FilePath $CsvFile -Append -Encoding UTF8
        }
        
        Write-Success "Processed $processedCount hosted zone(s)"
        return $processedCount
    }
    catch {
        Write-Error "Failed to retrieve hosted zones. Please check your AWS permissions."
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Function to display summary
function Show-Summary {
    param(
        [string]$CsvFile,
        [int]$RecordCount
    )
    
    Write-Success "Export completed successfully!"
    Write-Host ""
    Write-Host "=== EXPORT SUMMARY ===" -ForegroundColor Yellow
    Write-Host "Output file: $CsvFile"
    Write-Host "Total records exported: $RecordCount"
    Write-Host "Export date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "AWS Region: $Region"
    Write-Host ""
    
    if ($RecordCount -gt 0 -and (Test-Path $CsvFile)) {
        Write-Info "Sample of exported data:"
        Write-Host "========================" -ForegroundColor Yellow
        Get-Content $CsvFile -Head 3 | ForEach-Object { Write-Host $_ }
        Write-Host "========================" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Main execution
function Main {
    Write-Host "===================================================================" -ForegroundColor Yellow
    Write-Host "              AWS Route 53 Information Export Tool" -ForegroundColor Yellow
    Write-Host "===================================================================" -ForegroundColor Yellow
    Write-Host "Region: $Region"
    Write-Host "Start time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "===================================================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Check prerequisites
    Test-AwsCli
    
    # Create output directory
    New-OutputDirectory -Path $OutputPath
    
    # Generate filename
    $csvFile = Get-CsvFileName -BasePath $OutputPath
    
    # Export Route 53 information
    $recordCount = Export-Route53Info -CsvFile $csvFile
    
    # Display summary
    Show-Summary -CsvFile $csvFile -RecordCount $recordCount
    
    Write-Host "===================================================================" -ForegroundColor Yellow
    Write-Host "Export completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "===================================================================" -ForegroundColor Yellow
}

# Execute main function
try {
    Main
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
