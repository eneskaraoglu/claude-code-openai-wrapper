# Starting the Server

Startup and recovery steps for the **Claude Code OpenAI API Wrapper** on Windows (PowerShell).

> The server runs from the in-project virtual environment at `.venv`.
> It listens on **http://127.0.0.1:8000**.

---

## 1. Normal start

Open PowerShell in the project folder (`C:\WORKSPACE\AI\claude-code-openai-wrapper`) and run:

```powershell
.\.venv\Scripts\python.exe -m uvicorn src.main:app --host 127.0.0.1 --port 8000
```

Leave this window open — the server runs as long as it stays open. To run in the background instead, use `Start-Process`:

```powershell
Start-Process -WindowStyle Hidden -FilePath ".\.venv\Scripts\python.exe" `
  -ArgumentList "-m","uvicorn","src.main:app","--host","127.0.0.1","--port","8000"
```

Then verify it's healthy:

```powershell
curl http://127.0.0.1:8000/health
# -> {"status":"healthy","service":"claude-code-openai-wrapper"}
```

---

## 2. Before starting: check Claude auth

The wrapper uses your logged-in Claude CLI. After a reboot, confirm you're still logged in:

```powershell
claude auth status
```

If `loggedIn` is `false`, re-login:

```powershell
claude auth login
```

---

## 3. Recovering from the "Failed to start Claude Code" error

**Symptom:** `/health` works, but chat requests return
`500 Internal Server Error` / `Failed to start Claude Code` or `No response from Claude Code`.

**Cause:** A stale server process (often left over after the computer sleeps, reboots, or sits idle) can no longer spawn the Claude subprocess. Its child process may also keep **port 8000** occupied, so a new server can't bind.

**Fix — free port 8000, then start fresh.** Paste this whole block into PowerShell:

```powershell
# Stop any process listening on port 8000 (and its children), then free the port
Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { taskkill /PID $_ /T /F 2>$null }

Start-Sleep -Milliseconds 800

# Confirm the port is free (no output = free)
Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
```

> **Note:** This only targets the process bound to port 8000, so it will **not** touch your interactive Claude Code / `claude` session.

Then start the server again using the command in [section 1](#1-normal-start).

---

## 4. Verify everything works

```powershell
# Health
curl http://127.0.0.1:8000/health

# A real chat completion (uses the default model, currently claude-haiku-4-5-20251001)
curl -X POST http://127.0.0.1:8000/v1/chat/completions `
  -H "Content-Type: application/json" `
  -d '{\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: it works\"}]}'
```

A successful response contains `"content":"it works"`. If you get a 500 instead, repeat [section 3](#3-recovering-from-the-failed-to-start-claude-code-error).

---

## 5. One-shot start script (recommended)

To avoid doing this manually every reboot, save the following as **`start.ps1`** in the project folder and just run `.\start.ps1`:

```powershell
# start.ps1 - free port 8000 if occupied, then launch the wrapper
$ErrorActionPreference = "SilentlyContinue"
Set-Location -Path $PSScriptRoot

Write-Host "Checking Claude auth..." -ForegroundColor Cyan
claude auth status | Out-Host

Write-Host "Freeing port 8000 if in use..." -ForegroundColor Cyan
Get-NetTCPConnection -LocalPort 8000 -State Listen |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { taskkill /PID $_ /T /F 2>$null | Out-Null }
Start-Sleep -Milliseconds 800

Write-Host "Starting server on http://127.0.0.1:8000 ..." -ForegroundColor Green
& ".\.venv\Scripts\python.exe" -m uvicorn src.main:app --host 127.0.0.1 --port 8000
```

Run it with:

```powershell
.\start.ps1
```

Leave the window open while you use the API. Press `Ctrl+C` to stop the server.

---

## Quick reference

| Task | Command |
|------|---------|
| Start server | `.\.venv\Scripts\python.exe -m uvicorn src.main:app --host 127.0.0.1 --port 8000` |
| Check auth | `claude auth status` |
| Free port 8000 | `Get-NetTCPConnection -LocalPort 8000 -State Listen \| Select -Expand OwningProcess -Unique \| %{ taskkill /PID $_ /T /F }` |
| Health check | `curl http://127.0.0.1:8000/health` |
| Stop server | `Ctrl+C` in its window, or free port 8000 as above |

For API usage examples, see [USAGE.md](USAGE.md). For full configuration, see [README.md](README.md).
