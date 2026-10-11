<#
.SYNOPSIS
    Register this server as a GitHub Actions self-hosted runner.
    Run this ONCE on a fresh server, then trigger the full setup from GitHub Actions.

.EXAMPLE
    .\Register-Runner.ps1 -RunnerToken "AXXXXXXXXXXXXXXXXXXXXXXXXXX"
#>
param(
    [Parameter(Mandatory)][string]$RunnerToken,
    [string]$RunnerMode = "staging"
)

$ErrorActionPreference = "Stop"

$RUNNER_DIR = "C:\actions-runner"
$RUNNER_VER = "2.320.0"
$REPO_URL   = "https://github.com/altosecteam-org/Altosec-File-Server-v2"

Write-Host "==> Setting up GitHub Actions runner ($RunnerMode)"

if (-not (Test-Path "$RUNNER_DIR\config.cmd")) {
    New-Item -ItemType Directory -Force $RUNNER_DIR | Out-Null
    Write-Host "  Downloading runner v$RUNNER_VER ..."
    $zip = "$env:TEMP\actions-runner.zip"
    Invoke-WebRequest "https://github.com/actions/runner/releases/download/v$RUNNER_VER/actions-runner-win-x64-$RUNNER_VER.zip" -OutFile $zip
    Expand-Archive $zip $RUNNER_DIR -Force
    Write-Host "  Extracted to $RUNNER_DIR"
} else {
    Write-Host "  Runner already downloaded"
}

Set-Location $RUNNER_DIR

Write-Host "  Configuring runner..."
& .\config.cmd `
    --url   $REPO_URL `
    --token $RunnerToken `
    --name  "$RunnerMode-runner" `
    --labels $RunnerMode `
    --work  "_work" `
    --unattended `
    --replace

Write-Host "  Installing runner service..."
& .\svc.ps1 install
& .\svc.ps1 start

Write-Host ""
Write-Host "======================================================"
Write-Host "  Runner registered and running (label: $RunnerMode)"
Write-Host "======================================================"
Write-Host ""
Write-Host "  Next: trigger the setup workflow from GitHub --"
Write-Host "  https://github.com/altosecteam-org/Altosec-File-Server-v2/actions/workflows/setup-staging.yml"
Write-Host ""
