# Usage Guide

Practical examples for using the **Claude Code OpenAI API Wrapper**. The server exposes an OpenAI-compatible API backed by Claude, so any OpenAI client library works against it.

> **Base URL:** `http://localhost:8000`
> **OpenAI base URL:** `http://localhost:8000/v1`

## Contents
- [Start the server](#start-the-server)
- [Authentication](#authentication)
- [Quick check](#quick-check)
- [curl examples](#curl-examples)
- [OpenAI Python SDK](#openai-python-sdk)
- [OpenAI Node.js SDK](#openai-nodejs-sdk)
- [Streaming](#streaming)
- [Session continuity](#session-continuity)
- [Enabling tools](#enabling-tools)
- [Anthropic-native endpoint](#anthropic-native-endpoint)
- [LangChain](#langchain)
- [Troubleshooting](#troubleshooting)

---

## Start the server

This project uses an in-project virtual environment at `.venv`.

**Development mode (auto-reload):**
```powershell
.\.venv\Scripts\python.exe -m uvicorn src.main:app --reload --port 8000
```

**Production mode** (prompts to optionally enable API-key protection):
```powershell
.\.venv\Scripts\python.exe main.py
```

If you have Poetry on your PATH you can also use the documented commands:
```bash
poetry run uvicorn src.main:app --reload --port 8000
```

---

## Authentication

There are two distinct layers of auth — don't confuse them:

| Layer | What it is | Current setup |
|-------|-----------|---------------|
| **Claude auth** (server → Anthropic) | How the wrapper talks to Claude | Auto-detected from your logged-in Claude CLI |
| **Client auth** (you → wrapper) | An optional API key clients must send | **Disabled** (local-only access) |

Since client auth is disabled, you can use any placeholder for `api_key` in the examples below. If you later enable API-key protection, pass that key as a Bearer token:

```bash
curl -H "Authorization: Bearer YOUR_KEY" http://localhost:8000/v1/models
```

Check the current auth state any time:
```bash
curl http://localhost:8000/v1/auth/status
```

---

## Quick check

```bash
# Is it alive?
curl http://localhost:8000/health

# What models are available?
curl http://localhost:8000/v1/models
```

---

## curl examples

**Basic chat completion:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "messages": [
      {"role": "user", "content": "What is 2 + 2?"}
    ]
  }'
```

**With a system prompt:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "messages": [
      {"role": "system", "content": "You are a terse assistant. Answer in one sentence."},
      {"role": "user", "content": "Explain what an API is."}
    ]
  }'
```

The fastest/cheapest model is `claude-haiku-4-5-20251001` — handy for quick tests.

---

## OpenAI Python SDK

Install the client into the project venv (or any environment):
```powershell
.\.venv\Scripts\python.exe -m pip install openai
```

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",  # any string works while client auth is disabled
)

response = client.chat.completions.create(
    model="claude-sonnet-4-6",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Write a Python hello world script."},
    ],
)

print(response.choices[0].message.content)
print(f"Tokens: {response.usage.total_tokens} "
      f"({response.usage.prompt_tokens} prompt + {response.usage.completion_tokens} completion)")
```

See [examples/openai_sdk.py](examples/openai_sdk.py) for a runnable version.

---

## OpenAI Node.js SDK

```bash
npm install openai
```

```js
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://localhost:8000/v1",
  apiKey: "not-needed",
});

const response = await client.chat.completions.create({
  model: "claude-sonnet-4-6",
  messages: [{ role: "user", content: "Give me a haiku about TypeScript." }],
});

console.log(response.choices[0].message.content);
```

---

## Streaming

**Python SDK:**
```python
stream = client.chat.completions.create(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Explain quantum computing in 3 sentences."}],
    stream=True,
)

for chunk in stream:
    delta = chunk.choices[0].delta.content
    if delta:
        print(delta, end="", flush=True)
print()
```

**curl:**
```bash
curl -N -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "messages": [{"role": "user", "content": "Count from 1 to 5."}],
    "stream": true
  }'
```

See [examples/streaming.py](examples/streaming.py) for more.

---

## Session continuity

Pass a `session_id` to keep conversation context across requests — a feature beyond the standard OpenAI API. Sessions expire after 1 hour of inactivity.

```python
# First message
client.chat.completions.create(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "My name is Alice and I'm learning Python."}],
    extra_body={"session_id": "my-session"},
)

# Later request — Claude remembers
response = client.chat.completions.create(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "What's my name and what am I learning?"}],
    extra_body={"session_id": "my-session"},
)
print(response.choices[0].message.content)  # -> "Your name is Alice, and you're learning Python."
```

**curl** uses a top-level `session_id` field:
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "messages": [{"role": "user", "content": "My favourite colour is blue."}],
    "session_id": "my-session"
  }'
```

**Manage sessions:**
```bash
curl http://localhost:8000/v1/sessions               # list active sessions
curl http://localhost:8000/v1/sessions/my-session    # session details
curl -X DELETE http://localhost:8000/v1/sessions/my-session  # delete
curl http://localhost:8000/v1/sessions/stats         # statistics
```

See [examples/session_continuity.py](examples/session_continuity.py).

---

## Enabling tools

By default tools are **disabled** for speed and OpenAI compatibility. Enable Claude Code's tools (Read, Write, Bash, etc.) per request with `enable_tools`:

```python
response = client.chat.completions.create(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "What files are in the current directory?"}],
    extra_body={"enable_tools": True},
)
print(response.choices[0].message.content)  # Claude actually reads the directory
```

> Tools operate inside the server's working directory (`CLAUDE_CWD`, an isolated temp dir by default). Set `CLAUDE_CWD` in `.env` to point at a real workspace.

---

## Anthropic-native endpoint

The wrapper also speaks Anthropic's Messages API at `/v1/messages`:

```bash
curl -X POST http://localhost:8000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "system": "You are a helpful assistant.",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",
    model="claude-sonnet-4-6",
)

print(llm.invoke("Summarise the theory of relativity in one line.").content)
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Connection refused` | The server isn't running — start it (see [Start the server](#start-the-server)). |
| `401 Unauthorized` | Client API-key protection is enabled — pass `Authorization: Bearer YOUR_KEY`. |
| Auth errors from Claude | Run `claude auth status`; re-login with `claude auth login` if needed. |
| Slow / timeout on complex prompts | Increase `MAX_TIMEOUT` in `.env`; try `claude-haiku-4-5-20251001` for speed. |
| Model rejected | Use a supported model from `GET /v1/models` (Claude 3.x is not supported by the SDK). |

For full configuration and endpoint reference, see [README.md](README.md).
