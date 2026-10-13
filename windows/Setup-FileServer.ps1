<#
.SYNOPSIS
    Deploy or migrate the Altosec File Server on a fresh Windows Server.

.DESCRIPTION
    Downloads server-setup.ps1 from the app repo and runs it.
    All installation (Python, PostgreSQL, nginx, NSSM, Git) is handled
    automatically. Re-running is safe (idempotent).

.PREREQUISITES
    - Windows Server 2019 / 2022, PowerShell as Administrator
    - Domain A record pointing to this server's IP (required for SSL cert)
    - GitHub PAT with `repo` scope: https://github.com/settings/tokens
    - Backup .zip archive on this machine (restore mode only)

.EXAMPLE
    Restore mode (migration from existing server):

        & .\Setup-FileServer.ps1 `
            -Domain      "your-domain.com" `
            -GithubPat   "ghp_..." `
            -SecretKey   "BASE64_KEY" `
            -AdminUser   "admin" `
            -AdminHash   '$2b$12$HASH' `
            -DatabaseUrl "postgresql+asyncpg://fileserver_user:PASS@localhost:5432/fileserver" `
            -PgSuperPass "POSTGRES_PASS" `
            -JwtSecret   "BASE64_KEY" `
            -ApiSecret   "SECRET" `
            -TgToken     "BOT_TOKEN" `
            -TgChat      "CHAT_ID" `
            -RunnerMode  "staging" `
            -RunnerToken "RUNNER_TOKEN" `
            -RestoreMode "restore" `
            -BackupZip   "C:\backup-YYYY-MM-DD.zip"

    Fresh install (no existing data):

        & .\Setup-FileServer.ps1 `
            -Domain      "your-domain.com" `
            -GithubPat   "ghp_..." `
            ... (all params except -BackupZip) `
            -RestoreMode "fresh"

.NOTE
    -AdminHash must use single quotes so PowerShell does not expand $ in the bcrypt hash.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Domain,
    [Parameter(Mandatory)][string]$GithubPat,
    [Parameter(Mandatory)][string]$SecretKey,
    [Parameter(Mandatory)][string]$AdminUser,
    [Parameter(Mandatory)][string]$AdminHash,
    [Parameter(Mandatory)][string]$DatabaseUrl,
    [Parameter(Mandatory)][string]$PgSuperPass,
    [Parameter(Mandatory)][string]$JwtSecret,
    [Parameter(Mandatory)][string]$ApiSecret,
    [string]$TgToken     = "",
    [string]$TgChat      = "",
    [string]$DbxKey      = "",
    [string]$DbxSecret   = "",
    [string]$DbxRefresh  = "",
    [Parameter(Mandatory)][string]$RunnerMode,
    [Parameter(Mandatory)][string]$RunnerToken,
    [Parameter(Mandatory)]
    [ValidateSet("fresh","restore")][string]$RestoreMode,
    [string]$BackupZip   = ""
)

Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host ""
Write-Host "Downloading server-setup.ps1..." -ForegroundColor Cyan
Invoke-WebRequest `
    "https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2/main/scripts/server-setup.ps1" `
    -Headers @{ Authorization = "token $GithubPat" } `
    -OutFile "C:\server-setup.ps1"

Write-Host "Starting setup..." -ForegroundColor Cyan
& "C:\server-setup.ps1" @PSBoundParameters