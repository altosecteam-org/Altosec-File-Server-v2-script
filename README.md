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
| Backup `.zip` | Run the backup script on the **old** server first (see Step 1) |

---

### Step 1 — Create a backup on the old server

On the **old server**, open PowerShell as Administrator:

```powershell
C:\AltosecApp\scripts\backup.ps1
```

This produces a `.zip` at `%TEMP%\altosec_backup\backup-YYYY-MM-DD.zip`.

---

### Step 2 — Transfer backup to the new server

Copy the `.zip` to the new server, e.g.:

```
C:\backup-2026-10-11.zip
```

---

### Step 3 — Point DNS to the new server

The setup script obtains a TLS certificate — the domain **must resolve to the new server's IP** before running, and **port 80 must be open**.

Set an **A record** in your DNS provider:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `your-domain.com` | `NEW_SERVER_IP` | 60 |

Verify:
```powershell
Resolve-DnsName your-domain.com
```

---

### Step 4 — Register the GitHub Actions runner

> The runner token expires in **1 hour** — get it right before this step.

1. Go to: `https://github.com/altosecteam-org/Altosec-File-Server-v2/settings/actions/runners/new`
   → Windows / x64 → copy the token from the `--token` line

2. On the **new server**, open PowerShell as Administrator:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

Invoke-WebRequest `
    "https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/Register-Runner.ps1" `
    -OutFile "C:\Register-Runner.ps1"

& C:\Register-Runner.ps1 -RunnerToken "PASTE_TOKEN_HERE"
```

This registers the server as a GitHub Actions runner. No other credentials needed here.

---

### Step 5 — Trigger the setup from GitHub

1. Go to: `https://github.com/altosecteam-org/Altosec-File-Server-v2/actions/workflows/setup-staging.yml`
2. Click **Run workflow**
3. Fill in:
   - `backup_zip`: path to backup on server (e.g. `C:\backup-2026-10-11.zip`)
   - `restore_mode`: `restore`
4. Click **Run workflow**

All credentials are read automatically from GitHub environment secrets. Nothing to type.

---

### Step 6 — Verify

```powershell
sc query AltosecFileServer   # STATE: RUNNING
sc query nginx               # STATE: RUNNING
```

Open `https://your-domain.com` and `https://your-domain.com:2083` in a browser.

---

## Fresh install

Same as migration but skip Steps 1–2. In Step 5, set `restore_mode` to `fresh` and leave `backup_zip` empty.

---

## Generating credential values

**Secret key / JWT secret** (any machine with Python):
```powershell
python -c "import secrets,base64; print(base64.b64encode(secrets.token_bytes(32)).decode())"
```

**Admin password hash:**
```powershell
pip install bcrypt
python -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt(12)).decode())"
```
