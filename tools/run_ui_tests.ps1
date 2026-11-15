# runs the playwright ui tests. playwright starts the api (on inat_test_copy) and the angular app itself,
# so stop your own running api and web app first. the password is asked here and only lives for this run.
# usage, from the repo root:
#   .\tools\run_ui_tests.ps1           hidden browser, fastest
#   .\tools\run_ui_tests.ps1 -Headed   visible browser, slowed down so you can watch it click and type
param(
    [switch]$Headed
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:Path = "$env:Path;C:\Program Files\nodejs"

$passwordSecure = Read-Host "Password for jay" -AsSecureString
$env:E2E_USERNAME = "jay"
$env:E2E_PASSWORD = [System.Net.NetworkCredential]::new("", $passwordSecure).Password

$playwrightArguments = @("playwright", "test")
if ($Headed) {
    $playwrightArguments += "--headed"
    $env:E2E_SLOW_MOTION_MILLISECONDS = "400"
}

Push-Location (Join-Path $repositoryRoot "web")
npx @playwrightArguments
$exitCode = $LASTEXITCODE
Pop-Location

Remove-Item Env:E2E_PASSWORD
Remove-Item Env:E2E_USERNAME
Remove-Item Env:E2E_SLOW_MOTION_MILLISECONDS -ErrorAction SilentlyContinue

if ($exitCode -eq 0) {
    Write-Host "all ui tests passed" -ForegroundColor Green
}
else {
    Write-Host "some ui tests failed. open the report with: cd web; npx playwright show-report" -ForegroundColor Red
}

exit $exitCode