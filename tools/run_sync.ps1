# runs the local sync (databricks gold -> sql server) when there is something new to sync.
# made for the windows scheduled task from register_sync_task.ps1, but can be run by hand.
# it syncs only when the latest finished databricks run succeeded and ended after the last succeeded sync started.
# on sundays it does a full extract, so rows deleted in gold are deleted here too.
# every line, python output included, is written to logs\sync as it happens. the newest 30 logs are kept.
# usage, from the repo root:
#   .\tools\run_sync.ps1           sync if there is a new succeeded run
#   .\tools\run_sync.ps1 -Force    sync even without a new run
#   .\tools\run_sync.ps1 -Full     full extract, any day
param(
    [switch]$Force,
    [switch]$Full
)

[string]$repositoryRoot = Split-Path -Parent $PSScriptRoot
[string]$pythonPath = Join-Path $repositoryRoot ".venv\Scripts\python.exe"
[string]$syncScript = Join-Path $repositoryRoot "sync\sync_gold.py"
[string]$logFolder = Join-Path $repositoryRoot "logs\sync"
[string]$databricksProfile = "dbc-609647e1-c073"
[string]$jobName = "inat_taxonomy_pipeline"
[int]$logsToKeep = 30

New-Item -ItemType Directory -Force -Path $logFolder | Out-Null
[string]$logPath = Join-Path $logFolder "sync_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# one line to the screen and to the log file, written at once so a killed run still leaves its log
function Write-LogLine([string]$line) {
    Write-Host $line
    Add-Content -Path $logPath -Value $line -Encoding utf8
}

function Write-Log([string]$message) {
    Write-LogLine "$(Get-Date -Format 'HH:mm:ss')  $message"
}

# the start of the last succeeded sync in utc, or $null if there was none
function Get-LastSyncStart {
    [string[]]$output = & sqlcmd -S . -E -C -d inat -h -1 -W -b -Q "SET NOCOUNT ON; SELECT CONVERT(VARCHAR(23), MAX(StartedDate), 126) FROM sync.Run WHERE Status = 'Succeeded';"
    if ($LASTEXITCODE -ne 0) {
        throw "reading sync.Run failed"
    }

    [string]$value = ($output -join "").Trim()
    if ($value -eq "" -or $value -eq "NULL") {
        return $null
    }

    return [DateTimeOffset]::Parse($value + "Z")
}

# the latest finished run of the databricks job: its result and its end time in utc
function Get-LatestJobRun {
    [string[]]$jobsOutput = & databricks jobs list --name $jobName -o json -p $databricksProfile
    if ($LASTEXITCODE -ne 0) {
        throw "listing databricks jobs failed. if the login expired, run: databricks auth login --profile $databricksProfile"
    }

    [object[]]$jobs = @(($jobsOutput -join "`n") | ConvertFrom-Json)
    if ($jobs.Count -eq 0) {
        throw "job $jobName not found, deploy the bundle first"
    }

    [long]$jobId = $jobs[0].job_id
    [string[]]$runsOutput = & databricks jobs list-runs --job-id $jobId --completed-only --limit 1 -o json -p $databricksProfile
    if ($LASTEXITCODE -ne 0) {
        throw "listing databricks runs failed"
    }

    [object[]]$runs = @(($runsOutput -join "`n") | ConvertFrom-Json)
    if ($runs.Count -eq 0) {
        return $null
    }

    [object]$run = $runs[0]
    return [pscustomobject]@{
        RunId       = $run.run_id
        ResultState = $run.state.result_state
        EndTime     = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$run.end_time)
    }
}

[int]$exitCode = 0
try {
    Write-Log "sync check started"
    [object]$latestRun = Get-LatestJobRun
    [object]$lastSyncStart = Get-LastSyncStart

    [bool]$shouldSync = $Force.IsPresent
    if ($shouldSync -eq $false) {
        if ($latestRun -eq $null) {
            Write-Log "no finished databricks run yet, nothing to sync"
        }
        elseif ($latestRun.ResultState -ne "SUCCESS") {
            Write-Log "latest databricks run $($latestRun.RunId) ended $($latestRun.ResultState), not syncing"
            $exitCode = 1
        }
        elseif ($lastSyncStart -eq $null) {
            Write-Log "no succeeded sync yet, syncing"
            $shouldSync = $true
        }
        elseif ($latestRun.EndTime -gt $lastSyncStart) {
            Write-Log "databricks run $($latestRun.RunId) ended $($latestRun.EndTime.ToLocalTime()), after the last sync, syncing"
            $shouldSync = $true
        }
        else {
            Write-Log "nothing new since the last sync ($($lastSyncStart.ToLocalTime())), skipping"
        }
    }

    if ($shouldSync) {
        [string[]]$syncArguments = @("-u", $syncScript)
        [bool]$isSunday = (Get-Date).DayOfWeek -eq [DayOfWeek]::Sunday
        if ($Full.IsPresent -or $isSunday) {
            $syncArguments += "--full"
            Write-Log "full extract"
        }

        # every python line, errors included, goes through Write-LogLine as it arrives
        & $pythonPath @syncArguments 2>&1 | ForEach-Object { Write-LogLine "$_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Log "sync failed with exit code $LASTEXITCODE"
            $exitCode = 1
        }
        else {
            Write-Log "sync done"
        }
    }
}
catch {
    Write-Log "error: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    Get-ChildItem $logFolder -Filter "sync_*.log" | Sort-Object Name -Descending | Select-Object -Skip $logsToKeep | Remove-Item
}

exit $exitCode
