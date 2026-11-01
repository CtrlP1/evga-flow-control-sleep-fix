#Requires -RunAsAdministrator
# EVGA Flow Control Sleep Fix - uninstaller

$TaskName   = 'EVGA Flow Control Sleep Fix'
$InstallDir = Join-Path $env:ProgramData 'EVGAFlowControlSleepFix'

schtasks /Delete /TN $TaskName /F 2>$null | Out-Null
if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }

Write-Host "Removed '$TaskName' and $InstallDir." -ForegroundColor Green
