<#
.SYNOPSIS
    Bootstrap a new server: register GitHub Actions runner and trigger full setup.
    All server credentials are read from GitHub environment secrets automatically.

.EXAMPLE
    # Migration (restore from backup):
    & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/bootstrap.ps1'))) `
        -RunnerToken "AXXXXXXXXXXXXXXXXXXXXXXXXXX" `
        -GithubPat   "ghp_YOUR_PAT" `
        -BackupZip   "C:\backup-2026-10-11.zip"

    # Fresh install:
    & ([scriptblock]::Create((irm 'URL'))) -RunnerToken "TOKEN" -GithubPat "ghp_..." -RestoreMode "fresh"
#>
param(
    [Parameter(Mandatory)][string]$RunnerToken,
    [Parameter(Mandatory)][string]$GithubPat,
    [string]$BackupZip   = "skip",
    [string]$RestoreMode = "restore",
    [string]$RunnerMode  = "staging"
)

$ErrorActionPreference = "Stop"

$RUNNER_DIR = "C:\actions-runner"
$RUNNER_VER = "2.320.0"
$REPO_URL   = "https://github.com/altosecteam-org/Altosec-File-Server-v2"
$API_BASE   = "https://api.github.com/repos/altosecteam-org/Altosec-File-Server-v2"

# --- 1. Register runner ---
Write-Host ""
Write-Host "==> Registering GitHub Actions runner..."

if (-not (Test-Path "$RUNNER_DIR\config.cmd")) {
    New-Item -ItemType Directory -Force $RUNNER_DIR | Out-Null
    Write-Host "  Downloading runner v$RUNNER_VER..."
    $zip = "$env:TEMP\actions-runner.zip"
    Invoke-WebRequest "https://github.com/actions/runner/releases/download/v$RUNNER_VER/actions-runner-win-x64-$RUNNER_VER.zip" -OutFile $zip
    Expand-Archive $zip $RUNNER_DIR -Force
} else {
    Write-Host "  Runner already downloaded"
}

Set-Location $RUNNER_DIR

& .\config.cmd `
    --url        $REPO_URL `
    --token      $RunnerToken `
    --name       "$RunnerMode-runner" `
    --labels     $RunnerMode `
    --work       "_work" `
    --unattended `
    --replace

& .\svc.ps1 install
& .\svc.ps1 start

Write-Host "  Runner registered and running (label: $RunnerMode)"

# --- 2. Trigger setup workflow ---
Write-Host ""
Write-Host "==> Triggering setup-staging workflow..."

# Brief pause for runner to connect to GitHub
Start-Sleep 8

$headers = @{
    Authorization = "token $GithubPat"
    Accept        = "application/vnd.github.v3+json"
}

$body = @{
    ref    = "main"
    inputs = @{
        runner_token = "skip"
        restore_mode = $RestoreMode
        backup_zip   = $BackupZip
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod "$API_BASE/actions/workflows/setup-staging.yml/dispatches" `
    -Method Post -Headers $headers -Body $body -ContentType "application/json"

Write-Host "  Workflow triggered!"
Write-Host ""
Write-Host "======================================================"
Write-Host "  Setup is running. Monitor progress at:"
Write-Host "  https://github.com/altosecteam-org/Altosec-File-Server-v2/actions"
Write-Host "======================================================"
Write-Host ""
