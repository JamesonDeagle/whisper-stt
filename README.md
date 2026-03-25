# Whisper STT for macOS

Local speech-to-text for macOS using [OpenAI Whisper](https://github.com/openai/whisper) optimized for Apple Silicon via [MLX](https://github.com/ml-explore/mlx).

Replaces Apple Dictation with a faster, more accurate, fully offline alternative. Supports 100+ languages with automatic detection, handles mixed-language speech naturally.

![Waveform indicator](https://img.shields.io/badge/macOS-Apple%20Silicon-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Fully local** — nothing is sent to the internet, all processing happens on your Mac
- **Apple Silicon native** — runs on Metal GPU via Apple MLX framework
- **Fast** — ~1 second transcription for typical speech with the turbo model
- **Multi-language** — automatic language detection, handles mixed Russian/English, etc.
- **Visual feedback** — animated waveform pill overlay while recording
- **Model switching** — choose between turbo (fast), medium, or large (best quality) from the menubar
- **Auto-start** — daemon starts automatically on login via LaunchAgent

## How It Works

```
┌────────────────────────┐      ┌──────────────────────────┐
│   Hammerspoon (Lua)    │ HTTP │  Python STT Daemon       │
│  • Cmd+F5 hotkey       │◄────►│  • mlx_whisper model     │
│  • Waveform overlay    │      │  • sounddevice recording │
│  • Clipboard paste     │      │  • Auto-start on login   │
└────────────────────────┘      └──────────────────────────┘
```

1. Press **Cmd+F5** — recording starts, waveform pill appears at the bottom of the screen
2. Speak (any language)
3. Press **Cmd+F5** again — recording stops, Whisper transcribes, text is pasted into the active app
4. Press **Escape** to cancel recording

## Requirements

- macOS on **Apple Silicon** (M1/M2/M3/M4)
- ~2 GB free RAM (for the turbo model)
- ~1.5 GB disk space (for model weights)

## Installation

### One-command install

```bash
git clone https://github.com/JamesonDeagle/whisper-stt.git
cd whisper-stt
chmod +x install.sh
./install.sh
```

Or double-click **install.sh** in Finder.

The installer will:
1. Install [Hammerspoon](https://www.hammerspoon.org/) (if not present)
2. Create a Python virtual environment with `mlx-whisper` and `sounddevice`
3. Download the Whisper Large V3 Turbo model (~1.5 GB)
4. Set up Hammerspoon config with waveform overlay
5. Create and start a LaunchAgent for the daemon
6. Disable VoiceOver Cmd+F5 shortcut

### Manual steps after install

1. **Hammerspoon** will ask for Accessibility permission — allow it in System Settings > Privacy & Security > Accessibility
2. **Disable Apple Dictation shortcut**: System Settings > Keyboard > Dictation > change Shortcut to "Off" or "Press Control Twice"
3. Click Hammerspoon menubar icon (hammer) > **Reload Config**

### Verify

```bash
curl http://127.0.0.1:19876/status
# {"status": "idle", "model": "turbo"}
```

## Usage

| Action | Key |
|--------|-----|
| Start/stop recording | **Cmd+F5** |
| Cancel recording | **Escape** |
| Switch model | Menubar **W:turbo** > select |

## Models

Switch models from the **W:turbo** menubar menu. Models are downloaded on first use.

| Model | Parameters | Speed | Quality | Size |
|-------|-----------|-------|---------|------|
| **turbo** (default) | 809M | ~1s | Excellent | 1.5 GB |
| medium | 769M | ~1s | Good | 1.5 GB |
| large | 1.5B | ~2-3s | Best | 3 GB |

The turbo model is a distilled version of large-v3, offering 95-98% of its quality at 2-3x the speed.

## API

The daemon runs an HTTP server on `127.0.0.1:19876`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/toggle` | POST | Start/stop recording. Returns `{"status": "done", "text": "..."}` on stop |
| `/cancel` | POST | Cancel current recording |
| `/status` | GET | Current state: `loading`, `idle`, `recording`, `transcribing` |
| `/models` | GET | List available models |
| `/model` | POST | Switch model: `{"model": "turbo"}` |

## Uninstall

```bash
./uninstall.sh
```

This removes the daemon, LaunchAgent, virtual environment, and Hammerspoon config. Hammerspoon itself can be removed with `brew uninstall --cask hammerspoon`.

## Files

```
~/.whisper-stt/
├── whisper-stt-daemon.py    # Python daemon
├── venv/                    # Virtual environment
└── logs/                    # Daemon logs

~/.hammerspoon/
├── init.lua                 # Hotkey & overlay config
└── waveform.html            # Animated waveform pill

~/Library/LaunchAgents/
└── com.whisper.stt-daemon.plist
```

## Troubleshooting

**Cmd+F5 triggers VoiceOver or Apple Dictation**
- System Settings > Keyboard > Dictation > set Shortcut to "Off"
- System Settings > Accessibility > Voice Control > turn off
- The installer disables VoiceOver's Cmd+F5 automatically

**"STT daemon not running" alert**
- Check if the daemon is running: `curl http://127.0.0.1:19876/status`
- Check logs: `cat ~/.whisper-stt/logs/whisper-stt.err.log`
- Restart: `launchctl unload ~/Library/LaunchAgents/com.whisper.stt-daemon.plist && launchctl load ~/Library/LaunchAgents/com.whisper.stt-daemon.plist`

**No text appears after recording**
- Make sure the cursor is in a text field
- Check daemon logs for transcription results

**Microphone permission**
- On first run, macOS will ask for microphone permission for Python — allow it

## License

MIT
