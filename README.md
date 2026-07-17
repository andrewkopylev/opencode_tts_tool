# OpenCode Speak (TTS) Tool

Voice output for [OpenCode](https://opencode.ai) — the AI assistant can speak to the user via a TTS model, reading out answers, notifications, and task results.

The `speak` tool takes text, sends it to an OpenAI-compatible TTS API, receives audio, and plays it through a system audio player. The LLM is instructed to **summarize long text automatically** — full text is read aloud only when the user explicitly asks for it.

## Features

- **OpenAI-compatible API** — works with RouterAI, OpenRouter, or any proxy supporting `/v1/audio/speech`
- **Auto-detected audio player** — `paplay`, `mpv`, `ffplay`, `aplay`, `afplay` (Linux + macOS)
- **Adaptive format** — MP3 by default; WAV if only `aplay` is available
- **Auto-summarization** — the LLM receives an IMPORTANT instruction to shorten long text when speaking
- **Graceful fallback** — if no audio player is found, the audio file is saved to `/tmp`
- **Shared venv** — reuses `~/.config/opencode/tools/venv/` (no duplicate venvs)

## Use Cases

| Use Case | Example |
|----------|---------|
| **Notifications** | Assistant announces task completion: "Build finished, all tests passed" |
| **Confirmations** | Voice confirmation of an operation: "File saved, 3 records updated" |
| **Hands-free mode** | Hear results without looking at the screen |
| **Accessibility** | Alternative output channel for visually impaired users |

## Installation

```bash
git clone https://github.com/andrewkopylev/opencode_tts_tool.git
cd opencode_tts_tool
bash install.sh
```

The installer will:

1. Detect system Python 3
2. Create or reuse a venv at `~/.config/opencode/tools/venv/`
3. Install `openai` into the venv
4. Copy `speak.ts`, `speak.py` to `~/.config/opencode/tools/`
5. **Interactively** ask for TTS API credentials:
   - Base URL (default: `https://routerai.ru/api/v1`)
   - API Key
   - Model ID (default: `x-ai/grok-voice-tts-1.0`)
   - Voice (default: `eve`; options: `eve`, `ara`, `rex`, `sal`, `leo`)
6. Write `speak_config.json`

All files land in `~/.config/opencode/tools/` and become available to OpenCode on the next launch.

## Uninstall

```bash
bash uninstall.sh
```

Removes tool files (`speak.py`, `speak.ts`, `speak_config.json`). The shared venv is **not removed** (other tools may use it).

## Available Tools

| Tool | Purpose |
|------|---------|
| `speak` | Convert text to speech and play it through the system audio player |

## Example Usage in OpenCode

```
> Tell me what you just did

[AI analyzes completed work, summarizes]

[AI calls speak with text="Added three tests for the calculator, all pass.
Linter found no errors. Done."]

→ {"status": "spoken", "player": "mpv", "format": "mp3", "chars": 78}

> Read the full contents of README.md out loud

[AI calls speak with the full README.md text — user explicitly asked
to hear everything]

→ {"status": "spoken", "player": "mpv", "format": "mp3", "chars": 3420}
```

## Configuration

File `~/.config/opencode/tools/speak_config.json`:

```json
{
  "base_url": "https://routerai.ru/api/v1",
  "api_key": "YOUR_API_KEY",
  "model": "x-ai/grok-voice-tts-1.0",
  "voice": "eve"
}
```

| Parameter | Description |
|-----------|-------------|
| `base_url` | OpenAI-compatible TTS API base URL |
| `api_key` | API key for the TTS service |
| `model` | TTS model ID (default: `x-ai/grok-voice-tts-1.0`) |
| `voice` | Voice preset: `eve`, `ara`, `rex`, `sal`, `leo` (default: `eve`) |

### Changing the voice

Edit `voice` in the config — no reinstall needed, changes apply on the next `speak` call:

```bash
# Switch to the "ara" voice:
# Edit ~/.config/opencode/tools/speak_config.json → "voice": "ara"
```

### Switching TTS models

Any OpenAI-compatible model supporting `/v1/audio/speech` should work. Just update the `model` field in the config.

## Architecture

```
OpenCode Agent
     │  speak
     ▼
┌──────────────────────────────┐
│  speak.ts    (TypeScript)    │  ~/.config/opencode/tools/
│  Thin wrapper: Zod schema,   │
│  calls Python via Bun.spawn  │
│  + JSON stdin/stdout         │
└──────────────┬───────────────┘
               │ JSON over stdin/stdout
┌──────────────▼───────────────┐
│  speak.py    (Python)        │  ~/.config/opencode/tools/
│                               │
│  openai client ── TTS API    │
│  subprocess ───── audio play │
└──────────────┬───────────────┘
               │
    ┌──────────┴──────────┐
    ▼                     ▼
  TTS API              System audio
  (OpenAI-compatible)  player (paplay/
  /v1/audio/speech     mpv/ffplay/
                        aplay/afplay)
```

## Dependencies

- Python 3.8+
- `openai` — OpenAI-compatible API client (used for TTS)
- `httpx` — HTTP client (installed as an `openai` dependency)
- A system audio player (any of: `paplay`, `mpv`, `ffplay`, `aplay`, `afplay`)

All Python packages are installed into `~/.config/opencode/tools/venv/` by `install.sh`.

## License

MIT
