param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Username = "jay"
)

$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "k6\browse.js"
$reportPath = Join-Path $PSScriptRoot "k6\report.html"

# a terminal opened before k6 was installed has an old PATH, so reload it from the registry first
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

# still not on PATH: look in the usual install folders
if ($null -eq (Get-Command k6 -ErrorAction SilentlyContinue)) {
    $k6Exe = Get-ChildItem "C:\Program Files\k6", "C:\Program Files\GrafanaLabs", "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -Recurse -Filter k6.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $k6Exe) {
        throw "k6 not found. install it with: winget install k6 --source winget"
    }
    $env:Path = $k6Exe.DirectoryName + ";" + $env:Path
}

$securePassword = Read-Host "Password for $Username" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$exitCode = 1

try {
    $env:K6_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $env:K6_USERNAME = $Username
    $env:BASE_URL = $BaseUrl
    $env:K6_WEB_DASHBOARD = "true"
    $env:K6_WEB_DASHBOARD_OPEN = "true"
    $env:K6_WEB_DASHBOARD_PERIOD = "2s"
    $env:K6_WEB_DASHBOARD_EXPORT = $reportPath

    Write-Host "load test against $BaseUrl, the live dashboard opens in your browser..."
    k6 run $scriptPath
    $exitCode = $LASTEXITCODE
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Item Env:K6_PASSWORD, Env:K6_USERNAME, Env:BASE_URL, Env:K6_WEB_DASHBOARD, Env:K6_WEB_DASHBOARD_OPEN, Env:K6_WEB_DASHBOARD_PERIOD, Env:K6_WEB_DASHBOARD_EXPORT -ErrorAction SilentlyContinue
}

if (Test-Path $reportPath) {
    Write-Host "report saved: $reportPath"
    Start-Process $reportPath
}

exit $exitCode