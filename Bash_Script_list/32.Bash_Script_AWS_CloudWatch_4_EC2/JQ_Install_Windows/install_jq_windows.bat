@echo off
REM filepath: install_jq_windows.bat
REM Helper script to install jq on Windows

echo Installing jq for Windows...
echo.

REM Check if Chocolatey is available
where choco >nul 2>nul
if %ERRORLEVEL% == 0 (
    echo Found Chocolatey. Installing jq...
    choco install jq -y
    goto :end
)

REM Check if Scoop is available  
where scoop >nul 2>nul
if %ERRORLEVEL% == 0 (
    echo Found Scoop. Installing jq...
    scoop install jq
    goto :end
)

REM Check if winget is available
where winget >nul 2>nul
if %ERRORLEVEL% == 0 (
    echo Found winget. Installing jq...
    winget install -e --id jqlang.jq
    echo.
    echo jq has been installed via winget.
    echo Adding jq to system PATH...
    
    REM Add jq installation path to system PATH
    setx PATH "%PATH%;%LOCALAPPDATA%\Microsoft\WinGet\Packages\jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe" /M 2>nul
    if %ERRORLEVEL% neq 0 (
        echo Adding to user PATH instead...
        setx PATH "%PATH%;%LOCALAPPDATA%\Microsoft\WinGet\Packages\jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe"
    )
    
    echo.
    echo Please restart your terminal or run:
    echo export PATH="$PATH:/c/Users/%USERNAME%/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe"
    echo.
    goto :end
)

echo No package manager found. Please install jq manually:
echo 1. Download from: https://github.com/jqlang/jq/releases
echo 2. Extract jq.exe to a folder in your PATH
echo 3. Or use WSL: wsl apt-get install jq
echo 4. Or install via winget: winget install -e --id jqlang.jq

:end
echo Installation attempt completed.
echo Please restart your terminal and try running the script again.
echo.
echo If jq is still not found, manually add this to your PATH:
echo %LOCALAPPDATA%\Microsoft\WinGet\Packages\jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe
pause