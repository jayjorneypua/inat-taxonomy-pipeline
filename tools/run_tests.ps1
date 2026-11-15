# runs every test: the sql tests first (they also rebuild the test databases), then the c# tests.
# usage, from the repo root:  .\tools\run_tests.ps1        or   .\tools\run_tests.ps1 -RefreshCopy
param(
    [switch]$RefreshCopy
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "run_sql_tests.ps1") -RefreshCopy:$RefreshCopy
$sqlTestsExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "running the c# tests..."
dotnet test (Join-Path $repositoryRoot "api\Inat.slnx") --nologo
$dotnetTestsExitCode = $LASTEXITCODE

Write-Host ""
if (($sqlTestsExitCode -eq 0) -and ($dotnetTestsExitCode -eq 0)) {
    Write-Host "all tests passed" -ForegroundColor Green
    exit 0
}

Write-Host "some tests failed: sql exit code $sqlTestsExitCode, c# exit code $dotnetTestsExitCode" -ForegroundColor Red
exit 1