@echo off
REM Video to Text Workflow - one-click installer
REM Wrapper only: all real logic lives in scripts\install.ps1
setlocal
cd /d "%~dp0"

echo.
echo ==================================================
echo   Video to Text Workflow - Setup
echo ==================================================
echo.

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] powershell not found. Windows 10/11 required.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" %*
set RESULT=%errorlevel%

echo.
if not "%RESULT%"=="0" (
    echo [ERROR] Setup failed with code %RESULT%.
    echo Please scroll up and read the messages above.
) else (
    echo Done. You can close this window.
)
pause
