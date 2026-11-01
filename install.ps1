#Requires -RunAsAdministrator
# EVGA Flow Control Sleep Fix - installer
# Creates a wake-from-sleep scheduled task that resets the Asetek USB Device
# and restarts EVGA Flow Control, fixing "CPUWB - Device not found".

$TaskName   = 'EVGA Flow Control Sleep Fix'
$InstallDir = Join-Path $env:ProgramData 'EVGAFlowControlSleepFix'
$ScriptPath = Join-Path $InstallDir 'RestartFlowControl.ps1'
$FlowDir    = 'C:\Program Files (x86)\EVGA\Flow Control'

Write-Host "Installing $TaskName..." -ForegroundColor Cyan

# --- Checks ---------------------------------------------------------------
if (-not (Test-Path (Join-Path $FlowDir 'CPUWB.exe'))) {
    Write-Warning "EVGA Flow Control not found at: $FlowDir"
    Write-Warning "If it's installed elsewhere, edit `$FlowDir in $ScriptPath after install."
}

if (-not (Get-PnpDevice -FriendlyName 'Asetek USB Device' -PresentOnly -ErrorAction SilentlyContinue)) {
    Write-Warning "No 'Asetek USB Device' found in Device Manager."
    Write-Warning "Check Device Manager > Universal Serial Bus controllers for your pump's name,"
    Write-Warning "then edit `$DeviceName in $ScriptPath after install."
}

if (-not (Get-ScheduledTask -TaskName 'EVGA Flow Control' -ErrorAction SilentlyContinue)) {
    Write-Warning "EVGA's own 'EVGA Flow Control' startup task wasn't found."
    Write-Warning "The fix will launch CPUWB.exe /s directly instead."
}

# --- Write the wake script ------------------------------------------------
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

@'
# EVGA Flow Control Sleep Fix - runs on every wake from sleep
$FlowDir    = 'C:\Program Files (x86)\EVGA\Flow Control'
$DeviceName = 'Asetek USB Device'
$Log        = Join-Path $PSScriptRoot 'last-run.log'

function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content $Log }
"" | Set-Content $Log
Log 'Wake detected, starting fix'

# Let USB settle after wake
Start-Sleep -Seconds 5

# Close Flow Control and its server (also clears the error popup)
Get-Process CPUWB, CLCServer -ErrorAction SilentlyContinue | Stop-Process -Force
Log 'Closed CPUWB / CLCServer'

# Reset the pump's USB controller
$dev = Get-PnpDevice -FriendlyName $DeviceName -PresentOnly -ErrorAction SilentlyContinue
if ($dev) {
    $dev | Disable-PnpDevice -Confirm:$false
    Start-Sleep -Seconds 3
    $dev | Enable-PnpDevice -Confirm:$false
    Log "Reset device: $DeviceName"
} else {
    Log "Device not found: $DeviceName (nothing reset)"
}
Start-Sleep -Seconds 5

# Restart Flow Control the same way Windows does at boot (loads saved profile)
if (Get-ScheduledTask -TaskName 'EVGA Flow Control' -ErrorAction SilentlyContinue) {
    Start-ScheduledTask -TaskName 'EVGA Flow Control'
    Log "Started EVGA's 'EVGA Flow Control' task"
} else {
    Start-Process (Join-Path $FlowDir 'CPUWB.exe') -ArgumentList '/s' -WorkingDirectory $FlowDir
    Log 'Started CPUWB.exe /s'
}

# Make sure CLC Server is running too
Start-Sleep -Seconds 5
if (-not (Get-Process CLCServer -ErrorAction SilentlyContinue)) {
    Start-Process (Join-Path $FlowDir 'CLCServer.exe') -WorkingDirectory $FlowDir
    Log 'Started CLCServer.exe'
}
Log 'Done'
'@ | Set-Content -Path $ScriptPath -Encoding UTF8

# --- Create the wake task -------------------------------------------------
$filter = "*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]"
$action = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

schtasks /Create /TN $TaskName /SC ONEVENT /EC System /MO $filter /TR $action /RL HIGHEST /F | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Installed." -ForegroundColor Green
    Write-Host "  Script: $ScriptPath"
    Write-Host "  Task:   $TaskName (runs on every wake from sleep)"
    Write-Host ""
    Write-Host "Test now:  schtasks /Run /TN `"$TaskName`""
} else {
    Write-Error "Failed to create the scheduled task."
}
