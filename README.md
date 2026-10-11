# Altosec File Server

## Deploy

Open **PowerShell as Administrator** on the target Windows Server:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

Invoke-WebRequest `
    "https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/Setup-FileServer.ps1" `
    -OutFile "C:\Setup-FileServer.ps1"

& C:\Setup-FileServer.ps1 -GithubPat "ghp_..." [params]
```

A valid GitHub PAT is required to proceed.
