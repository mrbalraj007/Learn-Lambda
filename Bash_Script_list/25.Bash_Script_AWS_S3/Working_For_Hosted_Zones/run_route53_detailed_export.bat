@echo off
REM Batch file to run Route 53 detailed records export
REM Author: Professional AWS DevOps Engineer

echo.
echo ===================================================================
echo  AWS Route 53 Detailed Records Export Tool - Windows Launcher
echo ===================================================================
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell is not available on this system.
    echo Please install PowerShell or use the bash script instead.
    pause
    exit /b 1
)

echo [INFO] Starting Route 53 detailed records export...
echo.

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "Export-Route53RecordsDetailed.ps1" -Region "ap-southeast-2"

if errorlevel 1 (
    echo.
    echo [ERROR] Export failed. Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Export completed successfully!
echo Check the route53_exports folder for your CSV file.
echo.
pause
