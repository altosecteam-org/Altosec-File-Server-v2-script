# Altosec File Server

Server migration and setup guide.

---

## Prerequisites

| Item | Notes |
|---|---|
| Windows Server 2019 / 2022 | Fresh VPS recommended |
| GitHub PAT (`repo` scope) | [github.com/settings/tokens](https://github.com/settings/tokens) → Generate new token (classic) → check **repo** |
| Backup `.zip` | From the previous server's backup script |

---

## Step 1 — Point DNS to the new server

The setup script obtains a TLS certificate via HTTP-01 validation — the domain **must resolve to the new server's IP before running the script**, and **port 80 must be open**.

1. Find the new server's public IP from your VPS provider
2. Set an **A record** in your DNS provider:

   | Type | Name | Value | TTL |
   |---|---|---|---|
   | A | `your-domain.com` | `NEW_SERVER_IP` | 60 |

3. Verify propagation:
   ```powershell
   Resolve-DnsName your-domain.com
   ```
   Wait until it returns the new server's IP.

---

## Step 2 — Get a GitHub Actions runner token

> The token expires in **1 hour** — do this immediately before running the script.

1. Go to: `https://github.com/altosecteam-org/Altosec-File-Server-v2/settings/actions/runners/new`
2. Select **Windows**, **x64**
3. Copy the token from the `--token` line in the **Configure** section

---

## Step 3 — Copy backup to the new server

Transfer your `.zip` backup archive to the new server and place it at a known path, e.g. `C:\backup-2026-10-11.zip`.

(Skip if doing a fresh install with no existing data.)

---

## Step 4 — Run the setup script

Open **PowerShell as Administrator** on the new server:

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
    -RunnerToken    "RUNNER_TOKEN_FROM_STEP_2" `
    -RestoreMode    "restore" `
    -BackupZip      "C:\backup-2026-10-11.zip"
```

> **`-AdminHash` must use single quotes** so PowerShell does not expand `$` inside the bcrypt hash.
>
> For a fresh install with no existing data, set `-RestoreMode "fresh"` and omit `-BackupZip`.

The script takes **10–15 minutes** on first run. Re-runs complete in under **1 minute** (all steps are idempotent).

### Generating values

**Secret key / JWT secret** (run on any machine with Python):
```powershell
python -c "import secrets,base64; print(base64.b64encode(secrets.token_bytes(32)).decode())"
```

**Admin password hash:**
```powershell
pip install bcrypt
python -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt(12)).decode())"
```

---

## Step 5 — Verify

```powershell
sc query AltosecFileServer   # STATE: RUNNING
sc query nginx               # STATE: RUNNING
```

Then open `https://your-domain.com` and `https://your-domain.com:2083` in a browser.
