# Altosec File Server

Choose your setup mode:

- **[Migration](#migration-restore-from-backup)** — moving to a new server with existing data
- **[Fresh install](#fresh-install)** — brand new server, no existing data

---

## Migration (restore from backup)

### Prerequisites

| Item | Notes |
|---|---|
| Windows Server 2019 / 2022 | The **new** server |
| GitHub PAT (`repo` scope) | [github.com/settings/tokens](https://github.com/settings/tokens) → Generate new token (classic) → check **repo** |
| GitHub environment secrets | Must be configured in the `staging` environment before running |
| Backup `.zip` | Created in Step 1 below |

---

### Step 1 — Create a backup on the old server

On the **old server**, open PowerShell as Administrator:

```powershell
C:\AltosecApp\scripts\backup.ps1
```

Produces a `.zip` at `%TEMP%\altosec_backup\backup-YYYY-MM-DD.zip`.

---

### Step 2 — Transfer backup to the new server

Copy the `.zip` to the new server, e.g. `C:\backup-2026-10-11.zip`.

---

### Step 3 — Point DNS to the new server

The setup obtains a TLS certificate — the domain **must resolve to the new server's IP** before running, and **port 80 must be open**.

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `your-domain.com` | `NEW_SERVER_IP` | 60 |

Verify: `Resolve-DnsName your-domain.com`

---

### Step 4 — Get a runner token

> Expires in **1 hour** — do this immediately before Step 5.

Go to: `https://github.com/altosecteam-org/Altosec-File-Server-v2/settings/actions/runners/new`
→ Windows / x64 → copy the token from the `--token` line.

---

### Step 5 — Bootstrap (one command)

Open **PowerShell as Administrator** on the new server:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/bootstrap.ps1'))) `
    -RunnerToken "PASTE_RUNNER_TOKEN" `
    -GithubPat   "ghp_YOUR_PAT" `
    -BackupZip   "C:\backup-2026-10-11.zip"
```

This will:
1. Register this server as a GitHub Actions runner
2. Trigger the full setup workflow automatically
3. All credentials are pulled from GitHub environment secrets — nothing else to type

Monitor progress at:
`https://github.com/altosecteam-org/Altosec-File-Server-v2/actions`

---

### Step 6 — Verify

```powershell
sc query AltosecFileServer   # STATE: RUNNING
sc query nginx               # STATE: RUNNING
```

Open `https://your-domain.com` and `https://your-domain.com:2083` in a browser.

---

## Fresh install

Same as migration, skip Steps 1–2, and change Step 5:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/bootstrap.ps1'))) `
    -RunnerToken "PASTE_RUNNER_TOKEN" `
    -GithubPat   "ghp_YOUR_PAT" `
    -RestoreMode "fresh"
```

---

## Generating credential values

**Secret key / JWT secret:**
```powershell
python -c "import secrets,base64; print(base64.b64encode(secrets.token_bytes(32)).decode())"
```

**Admin password hash:**
```powershell
pip install bcrypt
python -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt(12)).decode())"
```
