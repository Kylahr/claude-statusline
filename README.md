# claude-statusline

A PowerShell statusline for [Claude Code](https://claude.com/claude-code) on Windows.

Shows: working directory, git branch, model name, context token usage, 5-hour rate limit, and weekly rate limit (with reset timers).

## Install (one command)

Run in PowerShell:

```powershell
irm https://raw.githubusercontent.com/Kylahr/claude-statusline/main/install.ps1 | iex
```

This will:

1. Download `statusline.ps1` to `~/.claude/statusline-command.ps1`
2. Patch `~/.claude/settings.json` to register it as your `statusLine`

Restart Claude Code afterwards.

## Manual install

```powershell
git clone https://github.com/Kylahr/claude-statusline.git
cd claude-statusline
./install.ps1
```

## What it shows

```
~/Desktop/Projekte | main | Opus 4.7 1M | ctx 42k/1.0M | 5h [████░░░░]  52% (2h14m) | wk [██░░░░░░]  23% (4d11h)
```

- **cyan** — current directory (with `~` for home)
- **magenta** — git branch (if inside a repo)
- **yellow** — model display name
- **green** — context tokens used / max (auto-detects 1M context)
- **blue** — 5-hour rate limit bar + reset
- **orange** — weekly rate limit bar + reset

## Uninstall

Delete the `statusLine` block from `~/.claude/settings.json` and delete `~/.claude/statusline-command.ps1`.

## Requirements

- Windows with PowerShell 5.1+ (ships by default)
- A terminal that renders ANSI escape codes (Windows Terminal works; the legacy conhost may not)
