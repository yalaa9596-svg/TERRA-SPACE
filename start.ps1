param(
    [string]$Device = ""
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $RootDir "smart_crop_backend"
$AppDir = Join-Path $RootDir "smart_crop_app"

# Ensure Flutter and Git are in PATH for this session
$extraPaths = @("D:\flutter\bin", "D:\mingit\cmd")
foreach ($p in $extraPaths) {
    if ((Test-Path $p) -and ($env:Path -notlike "*$p*")) {
        $env:Path = "$p;$env:Path"
    }
}

Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Smart Crop Doctor & Crop Rotation Explorer" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

# 1. Start FastAPI Backend in a separate window if port 8000 is not already listening
$port8000 = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if (-not $port8000) {
    Write-Host "[1/2] Starting FastAPI Backend on http://localhost:8000 ..." -ForegroundColor Cyan
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoExit", "-Command", "Set-Location '$BackendDir'; python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000" `
        -WorkingDirectory $BackendDir
    Start-Sleep -Seconds 2
} else {
    Write-Host "[1/2] FastAPI Backend already running on port 8000." -ForegroundColor Yellow
}

# 2. Pick target Flutter device (default to chrome unless specified)
if ([string]::IsNullOrWhiteSpace($Device)) {
    $Device = "chrome"
}

Write-Host "[2/2] Launching Flutter App on '$Device' ..." -ForegroundColor Cyan
Set-Location $AppDir
flutter run -d $Device

