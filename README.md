# claude-statusline

A PowerShell statusline for [Claude Code](https://claude.com/claude-code) on Windows.

Shows: working directory, git branch, model name, context token usage, session timer, and 5-hour + weekly rate limits (with reset timers). Segments auto-wrap into rows when the terminal is narrow.

## Install (one command)

Run in PowerShell:

```powershell
irm https://raw.githubusercontent.com/Kylahr/claude-statusline/main/install.ps1 | iex
```

This will:

1. Download `statusline.ps1` to `~/.claude/statusline-command.ps1`
2. Patch `~/.claude/settings.json` to register it as your `statusLine` with `refreshInterval: 10` so the session timer keeps ticking during idle

Restart Claude Code afterwards.

## Manual install

```powershell
git clone https://github.com/Kylahr/claude-statusline.git
cd claude-statusline
./install.ps1
```

## What it shows

```
~/Desktop/Projekte | main | Opus 4.7 1M | ctx 42k/1.0M | Session: 12m34s | 5h [████    ]  52% (2h14m) | wk [██      ]  23% (4d11h)
```

- **cyan** — current directory (with `~` for home)
- **magenta** — git branch (if inside a repo)
- **yellow** — model display name
- **green** — context tokens used / max
- **white** — session elapsed time (from `cost.total_duration_ms`)
- **red** — 5-hour rate limit bar + reset
- **orange** — weekly rate limit bar + reset

### Auto-wrapping

If your terminal is too narrow to fit everything, segments pack into multiple rows greedily. The window width is detected via `[Console]::WindowWidth`; if detection fails, it falls back to 120 columns.

Override the width manually by setting the `CLAUDE_STATUSLINE_WIDTH` env var before launching Claude Code:

```powershell
$env:CLAUDE_STATUSLINE_WIDTH = "80"; claude
```

## Uninstall

Delete the `statusLine` block from `~/.claude/settings.json` and delete `~/.claude/statusline-command.ps1`.

## Requirements

- Windows with PowerShell 5.1+ (ships by default)
- A terminal that renders ANSI escape codes (Windows Terminal works; the legacy conhost may not)
