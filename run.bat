@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "DEVICE=%~1"
if "%DEVICE%"=="" (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start.ps1"
) else (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start.ps1" -Device "%DEVICE%"
)

