<#
.SYNOPSIS
    Bootstrap a new server: register GitHub Actions runner and trigger full setup.
    All server credentials are read from GitHub environment secrets automatically.

.EXAMPLE
    # Migration (restore from backup):
    & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/bootstrap.ps1'))) `
        -RunnerToken "AXXXXXXXXXXXXXXXXXXXXXXXXXX" `
        -GithubPat   "ghp_YOUR_PAT" `
        -Domain      "your-domain.com" `
        -BackupZip   "C:\deploy\backup-2026-10-13.zip"

    # Fresh install:
    & ([scriptblock]::Create((irm 'URL'))) -RunnerToken "TOKEN" -GithubPat "ghp_..." -Domain "your-domain.com" -RestoreMode "fresh"
#>
param(
    [Parameter(Mandatory)][string]$RunnerToken,
    [Parameter(Mandatory)][string]$GithubPat,
    [Parameter(Mandatory)][string]$Domain,
    [string]$BackupZip   = "skip",
    [string]$RestoreMode = "restore",
    [string]$RunnerMode  = "staging"
)

$ErrorActionPreference = "Stop"

$RUNNER_DIR = "C:\actions-runner"
$REPO_URL   = "https://github.com/altosecteam-org/Altosec-File-Server-v2"
$API_BASE   = "https://api.github.com/repos/altosecteam-org/Altosec-File-Server-v2"

# --- 1. Register runner ---
Write-Host ""
Write-Host "==> Registering GitHub Actions runner..."

# Always fetch latest version and re-download if outdated
Write-Host "  Fetching latest runner version..."
$release    = Invoke-RestMethod "https://api.github.com/repos/actions/runner/releases/latest"
$RUNNER_VER = $release.tag_name -replace '^v', ''

$installedVer = ""
$verFile = "$RUNNER_DIR\.runner-version"
if (Test-Path $verFile) { $installedVer = (Get-Content $verFile).Trim() }

if ($installedVer -ne $RUNNER_VER) {
    Write-Host "  Downloading runner v$RUNNER_VER (installed: '$installedVer')..."
    if (Test-Path $RUNNER_DIR) {
        # Stop running runner before deleting (avoids locked DLL errors)
        schtasks /End    /TN "GitHubActionsRunner" 2>$null | Out-Null
        schtasks /Delete /TN "GitHubActionsRunner" /F 2>$null | Out-Null
        Stop-Process -Name "Runner.Listener" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "Runner.Worker"   -Force -ErrorAction SilentlyContinue
        Start-Sleep 4
        Remove-Item $RUNNER_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Force $RUNNER_DIR | Out-Null
    $zip = "$env:TEMP\actions-runner.zip"
    Invoke-WebRequest "https://github.com/actions/runner/releases/download/v$RUNNER_VER/actions-runner-win-x64-$RUNNER_VER.zip" -OutFile $zip
    Expand-Archive $zip $RUNNER_DIR -Force
    Set-Content $verFile $RUNNER_VER
} else {
    Write-Host "  Runner v$RUNNER_VER already up to date"
}

& "$RUNNER_DIR\config.cmd" `
    --url        $REPO_URL `
    --token      $RunnerToken `
    --name       "$RunnerMode-runner" `
    --labels     $RunnerMode `
    --work       "_work" `
    --unattended `
    --replace

# svc.ps1 was removed in newer runner versions — use a scheduled task instead
Write-Host "  Installing runner as startup task..."
schtasks /Create /TN "GitHubActionsRunner" /TR "cmd /c cd /d $RUNNER_DIR && run.cmd" /SC ONSTART /RU SYSTEM /F | Out-Null
schtasks /Run /TN "GitHubActionsRunner" | Out-Null

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
        github_pat   = $GithubPat
        runner_token = "skip"
        domain       = $Domain
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
