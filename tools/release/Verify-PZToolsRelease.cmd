@echo off
setlocal

if "%~1"=="" (
    echo Usage: %~nx0 "C:\path\to\extracted\PZTools-release" [additional PowerShell options]
    echo.
    echo Example:
    echo   %~nx0 "C:\PZ_Mapping_Tools\release\PZTools-Modernized-v1.0.0-Restored" -WriteManifest
    exit /b 2
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify-PZToolsRelease.ps1" %*
exit /b %ERRORLEVEL%
