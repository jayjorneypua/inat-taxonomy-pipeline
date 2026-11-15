# runs every sql test against a test database, never against inat.
#   inat_test_empty  recreated from the dacpac on every run: schema and seeds, no data
#   inat_test_copy   a restored copy of inat with real data. made on the first run, or with -RefreshCopy
# a test file fails when sqlcmd reports an error or the output contains FAILED.
# usage, from the repo root:  .\tools\run_sql_tests.ps1        or   .\tools\run_sql_tests.ps1 -RefreshCopy
param(
    [switch]$RefreshCopy
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$databaseProject = Join-Path $repositoryRoot "database\inat.sqlproj"
$dacpacPath = Join-Path $repositoryRoot "database\bin\Debug\inat.dacpac"
$testFolder = Join-Path $repositoryRoot "tests\sql"
$resultFolder = Join-Path $testFolder "results"
$emptyDatabase = "inat_test_empty"
$copyDatabase = "inat_test_copy"

# which database each test runs against
$testsByDatabase = [ordered]@{
    $emptyDatabase = @(
        "test_tree_procs.sql",
        "test_effective_access.sql",
        "test_login_procs.sql",
        "test_session_procs.sql",
        "test_user_grid.sql",
        "test_sync_merges.sql",
        "test_sync_all.sql"
    )
    $copyDatabase = @(
        "test_dashboard_procs.sql",
        "test_chart_grid_procs.sql"
    )
}

function Get-ConnectionString([string]$databaseName) {
    return "Server=.;Database=$databaseName;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
}

Write-Host "building the database project..."
dotnet build $databaseProject --nologo -v quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "the database project did not build" -ForegroundColor Red
    exit 1
}

Write-Host "recreating $emptyDatabase from the dacpac..."
sqlpackage /Action:Publish /SourceFile:$dacpacPath /TargetConnectionString:"$(Get-ConnectionString $emptyDatabase)" /p:CreateNewDatabase=True /Quiet:True
if ($LASTEXITCODE -ne 0) {
    Write-Host "publishing $emptyDatabase failed" -ForegroundColor Red
    exit 1
}

$copyExistsOutput = sqlcmd -S . -E -C -N -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'$copyDatabase'"
$copyExists = ($copyExistsOutput | Out-String).Trim() -eq "1"

if ($RefreshCopy -or ($copyExists -eq $false)) {
    Write-Host "making $copyDatabase from a backup of inat (takes a few minutes)..."
    sqlcmd -S . -E -C -N -b -i (Join-Path $repositoryRoot "tools\sql\refresh_test_copy.sql")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "refreshing $copyDatabase failed" -ForegroundColor Red
        exit 1
    }
}

# the copy may be older than the code: bring its schema up to date, data stays
Write-Host "updating the schema of $copyDatabase..."
sqlpackage /Action:Publish /SourceFile:$dacpacPath /TargetConnectionString:"$(Get-ConnectionString $copyDatabase)" /Quiet:True
if ($LASTEXITCODE -ne 0) {
    Write-Host "publishing $copyDatabase failed" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $resultFolder -Force | Out-Null

$failedTests = @()
$passedCount = 0

foreach ($databaseName in $testsByDatabase.Keys) {
    foreach ($testFile in $testsByDatabase[$databaseName]) {
        $testPath = Join-Path $testFolder $testFile
        $resultPath = Join-Path $resultFolder ($testFile -replace "\.sql$", ".log")

        $testOutput = sqlcmd -S . -E -C -N -b -W -I -d $databaseName -i $testPath 2>&1
        $exitCode = $LASTEXITCODE
        $testOutputText = $testOutput | Out-String
        Set-Content -Path $resultPath -Value $testOutputText

        $hasFailed = ($exitCode -ne 0) -or ($testOutputText -match "FAILED")

        if ($hasFailed) {
            $failedTests += $testFile
            Write-Host ("FAIL  {0,-30} on {1}   see {2}" -f $testFile, $databaseName, $resultPath) -ForegroundColor Red
        }
        else {
            $passedCount++
            Write-Host ("PASS  {0,-30} on {1}" -f $testFile, $databaseName) -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "$passedCount passed, $($failedTests.Count) failed"

if ($failedTests.Count -gt 0) {
    exit 1
}