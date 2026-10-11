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
| Backup `.zip` | Run the backup script on the **old** server first (see below) |

### Step 1 — Create a backup on the old server

On the **old server**, open PowerShell as Administrator:

```powershell
C:\AltosecApp\scripts\backup.ps1
```

This produces a `.zip` file at `%TEMP%\altosec_backup\backup-YYYY-MM-DD.zip`.

### Step 2 — Transfer backup to the new server

Copy the `.zip` to the new server at a known path, e.g.:

```
C:\backup-2026-10-11.zip
```

### Step 3 — Point DNS to the new server

The setup script obtains a TLS certificate — the domain **must resolve to the new server's IP** before running, and **port 80 must be open**.

Set an **A record** in your DNS provider:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `your-domain.com` | `NEW_SERVER_IP` | 60 |

Verify propagation:
```powershell
Resolve-DnsName your-domain.com
```

### Step 4 — Get a GitHub Actions runner token

> Expires in **1 hour** — do this right before running the script.

Go to: `https://github.com/altosecteam-org/Altosec-File-Server-v2/settings/actions/runners/new`
→ Windows / x64 → copy the token from the `--token` line.

### Step 5 — Run the setup script

Open **PowerShell as Administrator** on the **new server**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

Invoke-WebRequest `
    "https://raw.githubusercontent.com/altosecteam-org/Altosec-File-Server-v2-script/main/windows/Setup-FileServer.ps1" `
    -OutFile "C:\Setup-FileServer.ps1"

& C:\Setup-FileServer.ps1 `
    -Domain         "your-domain.com" `
    -GithubPat      "ghp_YOUR_PAT" `
    -SecretKey      "YOUR_SECRET_KEY" `
    -AdminUser      "YOUR_ADMIN_USERNAME" `
    -AdminHash      'YOUR_BCRYPT_HASH' `
    -DatabaseUrl    "postgresql+asyncpg://fileserver_user:DB_PASS@localhost:5432/fileserver" `
    -PgSuperPass    "POSTGRES_SUPERUSER_PASS" `
    -JwtSecret      "YOUR_JWT_SECRET" `
    -TgToken        "YOUR_TELEGRAM_BOT_TOKEN" `
    -TgChat         "YOUR_TELEGRAM_CHAT_ID" `
    -ApiSecret      "YOUR_API_SECRET" `
    -RunnerMode     "staging" `
    -RunnerToken    "RUNNER_TOKEN_FROM_STEP_4" `
    -RestoreMode    "restore" `
    -BackupZip      "C:\backup-2026-10-11.zip"
```

> **`-AdminHash` must use single quotes** so PowerShell does not expand `$` inside the bcrypt hash.

Takes **10–15 minutes** on first run.

### Step 6 — Verify

```powershell
sc query AltosecFileServer   # STATE: RUNNING
sc query nginx               # STATE: RUNNING
```

Open `https://your-domain.com` and `https://your-domain.com:2083` in a browser.

---

## Fresh install

Same steps as migration but skip Steps 1–2 and change the script call:

```powershell
& C:\Setup-FileServer.ps1 `
    -Domain         "your-domain.com" `
    -GithubPat      "ghp_YOUR_PAT" `
    -SecretKey      "YOUR_SECRET_KEY" `
    -AdminUser      "YOUR_ADMIN_USERNAME" `
    -AdminHash      'YOUR_BCRYPT_HASH' `
    -DatabaseUrl    "postgresql+asyncpg://fileserver_user:DB_PASS@localhost:5432/fileserver" `
    -PgSuperPass    "POSTGRES_SUPERUSER_PASS" `
    -JwtSecret      "YOUR_JWT_SECRET" `
    -TgToken        "YOUR_TELEGRAM_BOT_TOKEN" `
    -TgChat         "YOUR_TELEGRAM_CHAT_ID" `
    -ApiSecret      "YOUR_API_SECRET" `
    -RunnerMode     "staging" `
    -RunnerToken    "RUNNER_TOKEN" `
    -RestoreMode    "fresh"
```

---

## Generating values

**Secret key / JWT secret** (any machine with Python):
```powershell
python -c "import secrets,base64; print(base64.b64encode(secrets.token_bytes(32)).decode())"
```

**Admin password hash:**
```powershell
pip install bcrypt
python -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt(12)).decode())"
```
