#!/usr/bin/env python3
"""say.py — TTS backend for OpenCode 'say' tool.

Reads JSON from stdin, calls a TTS API (OpenAI-compatible) to synthesize
speech, then plays the audio through a system audio player.

Requirements: openai, httpx (installed via install.sh into shared venv)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

CONFIG_PATH = Path.home() / ".config" / "opencode" / "tools" / "say_config.json"


def load_config() -> dict:
    if CONFIG_PATH.exists():
        return json.loads(CONFIG_PATH.read_text())
    return {}


def find_audio_player() -> str | None:
    """Detect an available audio player, preferring lighter PulseAudio first."""
    for player in ("paplay", "mpv", "ffplay", "aplay", "afplay"):
        if shutil.which(player):
            return player
    return None


def get_response_format(player: str | None) -> str:
    """aplay only supports WAV; everything else handles MP3."""
    if player == "aplay":
        return "wav"
    return "mp3"


def play_audio(file_path: str, player: str) -> None:
    """Play an audio file via the given system player."""
    try:
        if player == "paplay":
            subprocess.run(["paplay", file_path], capture_output=True, timeout=120)
        elif player == "mpv":
            subprocess.run(
                ["mpv", "--no-video", "--no-terminal", file_path],
                capture_output=True,
                timeout=120,
            )
        elif player == "ffplay":
            subprocess.run(
                ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", file_path],
                capture_output=True,
                timeout=120,
            )
        elif player == "aplay":
            subprocess.run(["aplay", file_path], capture_output=True, timeout=120)
        elif player == "afplay":
            subprocess.run(["afplay", file_path], capture_output=True, timeout=120)
    except subprocess.TimeoutExpired:
        pass


def handle_say(payload: dict) -> str:
    config = load_config()
    text = payload.get("text", "")

    if not text.strip():
        return json.dumps({"error": "Empty text provided"})

    base_url = config.get("base_url", "")
    api_key = config.get("api_key", "")
    model = config.get("model", "x-ai/grok-voice-tts-1.0")
    voice = config.get("voice", "eve")

    if not base_url or not api_key:
        return json.dumps({
            "error": "TTS not configured (base_url or api_key missing). Run install.sh first."
        })

    player = find_audio_player()
    fmt = get_response_format(player)

    try:
        from openai import OpenAI
        import httpx  # noqa: E402

        client = OpenAI(
            api_key=api_key,
            base_url=base_url,
            max_retries=0,
            timeout=httpx.Timeout(connect=5.0, read=60.0, write=10.0, pool=5.0),
        )

        response = client.audio.speech.create(
            model=model,
            voice=voice,
            input=text,
            response_format=fmt,
        )

        tmp_path = tempfile.mktemp(suffix=f".{fmt}")
        response.stream_to_file(tmp_path)

    except Exception as e:
        return json.dumps({"error": f"TTS API error: {e}"})

    if player:
        play_audio(tmp_path, player)
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        return json.dumps({
            "status": "spoken",
            "player": player,
            "format": fmt,
            "chars": len(text),
        })
    else:
        return json.dumps({
            "status": "saved",
            "file": tmp_path,
            "chars": len(text),
            "message": "No audio player found. File saved to temp.",
        })


COMMANDS = {"say": handle_say}


def main() -> None:
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid JSON input: {e}"}))
        sys.exit(1)

    cmd = data.get("command", "")
    handler = COMMANDS.get(cmd)
    if handler:
        print(handler(data))
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
