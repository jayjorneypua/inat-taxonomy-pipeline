# runs the playwright ui tests. playwright starts the api (on inat_test_copy) and the angular app itself,
# so stop your own running api and web app first. jay's password is asked here and only lives for this run.
# usage, from the repo root:
#   .\tools\run_ui_tests.ps1           hidden browser, fastest
#   .\tools\run_ui_tests.ps1 -Headed   visible browser, slowed down so you can watch it click and type
param(
    [switch]$Headed
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$databaseProject = Join-Path $repositoryRoot "database\inat.sqlproj"
$dacpacPath = Join-Path $repositoryRoot "database\bin\Debug\inat.dacpac"
$apiProject = Join-Path $repositoryRoot "api\Inat.Api"
$createViewerScript = Join-Path $repositoryRoot "tools\sql\create_test_viewer.sql"
$webFolder = Join-Path $repositoryRoot "web"
$copyConnectionString = "Server=.;Database=inat_test_copy;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
$env:Path = "$env:Path;C:\Program Files\nodejs"

# a fixed password is fine here: e2e.viewer only exists in the local test copy
$viewerPassword = "E2E-Viewer-Password-1!"

$passwordSecure = Read-Host "Password for jay" -AsSecureString
$env:E2E_USERNAME = "jay"
$env:E2E_PASSWORD = [System.Net.NetworkCredential]::new("", $passwordSecure).Password

Write-Host "bringing the schema of inat_test_copy up to date..."
dotnet build $databaseProject --nologo -v quiet
sqlpackage /Action:Publish /SourceFile:$dacpacPath /TargetConnectionString:$copyConnectionString /Quiet:True
if ($LASTEXITCODE -ne 0) {
    Write-Host "publishing inat_test_copy failed" -ForegroundColor Red
    exit 1
}

Write-Host "creating the test viewer in inat_test_copy..."
$viewerHashOutput = dotnet run --project $apiProject -- hash-password $viewerPassword
$env:ViewerPasswordHash = $viewerHashOutput | Select-Object -Last 1
sqlcmd -S . -E -C -N -b -I -d inat_test_copy -i $createViewerScript
$viewerExitCode = $LASTEXITCODE
Remove-Item Env:ViewerPasswordHash
if ($viewerExitCode -ne 0) {
    Write-Host "creating the test viewer failed" -ForegroundColor Red
    exit 1
}

$env:E2E_VIEWER_USERNAME = "e2e.viewer"
$env:E2E_VIEWER_PASSWORD = $viewerPassword

$playwrightArguments = @("playwright", "test")
if ($Headed) {
    $playwrightArguments += "--headed"
    $env:E2E_SLOW_MOTION_MILLISECONDS = "400"
}

Push-Location $webFolder
npx @playwrightArguments
$exitCode = $LASTEXITCODE
Pop-Location

Remove-Item Env:E2E_PASSWORD
Remove-Item Env:E2E_USERNAME
Remove-Item Env:E2E_VIEWER_PASSWORD
Remove-Item Env:E2E_VIEWER_USERNAME
Remove-Item Env:E2E_SLOW_MOTION_MILLISECONDS -ErrorAction SilentlyContinue

if ($exitCode -eq 0) {
    Write-Host "all ui tests passed" -ForegroundColor Green
}
else {
    Write-Host "some ui tests failed. open the report with: cd web; npx playwright show-report" -ForegroundColor Red
}

exit $exitCode