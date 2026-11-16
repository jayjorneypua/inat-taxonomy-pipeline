# registers (or removes) the windows scheduled task that runs tools\run_sync.ps1 every day.
# it runs as the current user, only while logged on, so no password is stored.
# if the pc was off at the scheduled time, it runs as soon as it can.
# usage, from the repo root:
#   .\tools\register_sync_task.ps1                 daily at 06:00
#   .\tools\register_sync_task.ps1 -Time "07:30"   another time
#   .\tools\register_sync_task.ps1 -Unregister     removes the task
param(
    [string]$Time = "06:00",
    [switch]$Unregister
)

[string]$taskName = "inat sync gold"
[string]$repositoryRoot = Split-Path -Parent $PSScriptRoot
[string]$syncScript = Join-Path $repositoryRoot "tools\run_sync.ps1"

if ($Unregister.IsPresent) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "removed task '$taskName'"
    exit 0
}

[string]$userName = "$env:USERDOMAIN\$env:USERNAME"
[string]$arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$syncScript`""

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments -WorkingDirectory $repositoryRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$principal = New-ScheduledTaskPrincipal -UserId $userName -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName -Description "syncs databricks gold into sql server after the nightly job, see tools\run_sync.ps1" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "registered task '$taskName', daily at $Time as $userName"
Write-Host "logs: $(Join-Path $repositoryRoot 'logs\sync')"
