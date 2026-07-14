# start.ps1 - free port 8000 if occupied, then launch the wrapper
$ErrorActionPreference = "SilentlyContinue"
Set-Location -Path $PSScriptRoot

Write-Host "Checking Claude auth..." -ForegroundColor Cyan
claude auth status | Out-Host

Write-Host "Freeing port 8000 if in use..." -ForegroundColor Cyan
Get-NetTCPConnection -LocalPort 8000 -State Listen |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { taskkill /PID $_ /T /F 2>$null | Out-Null }
Start-Sleep -Milliseconds 800

Write-Host "Starting server on http://127.0.0.1:8000 ..." -ForegroundColor Green
& ".\.venv\Scripts\python.exe" -m uvicorn src.main:app --host 127.0.0.1 --port 8000
