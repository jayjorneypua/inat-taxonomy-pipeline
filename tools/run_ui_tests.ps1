# runs the playwright ui tests. playwright starts the api (on inat_test_copy) and the angular app itself,
# so stop your own running api and web app first. the password is asked here and only lives for this run.
# usage, from the repo root:  .\tools\run_ui_tests.ps1
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:Path = "$env:Path;C:\Program Files\nodejs"

$passwordSecure = Read-Host "Password for jay" -AsSecureString
$env:E2E_USERNAME = "jay"
$env:E2E_PASSWORD = [System.Net.NetworkCredential]::new("", $passwordSecure).Password

Push-Location (Join-Path $repositoryRoot "web")
npx playwright test
$exitCode = $LASTEXITCODE
Pop-Location

Remove-Item Env:E2E_PASSWORD
Remove-Item Env:E2E_USERNAME

if ($exitCode -eq 0) {
    Write-Host "all ui tests passed" -ForegroundColor Green
}
else {
    Write-Host "some ui tests failed. open the report with: cd web; npx playwright show-report" -ForegroundColor Red
}

exit $exitCode