@echo off
REM ==============================================================================
REM Script Name: run_route53_export.bat
REM Description: Windows batch file to run Route 53 export script
REM Author: AWS DevOps Engineer
REM Date: 2025-07-01
REM Version: 1.0
REM ==============================================================================

echo =================================================================
echo              AWS Route 53 Information Export Tool
echo =================================================================
echo.

REM Check if WSL is available
wsl --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: WSL (Windows Subsystem for Linux) is not installed or not available.
    echo Please install WSL to run this bash script on Windows.
    echo.
    echo Installation instructions:
    echo 1. Open PowerShell as Administrator
    echo 2. Run: wsl --install
    echo 3. Restart your computer
    echo 4. Set up a Linux distribution
    echo.
    pause
    exit /b 1
)

REM Check if the bash script exists
if not exist "export_route53_info.sh" (
    echo ERROR: export_route53_info.sh not found in current directory.
    echo Please ensure the script is in the same directory as this batch file.
    echo.
    pause
    exit /b 1
)

echo Running Route 53 export script via WSL...
echo.

REM Make the script executable and run it
wsl chmod +x export_route53_info.sh
wsl ./export_route53_info.sh

echo.
echo =================================================================
echo Script execution completed.
echo =================================================================
pause
