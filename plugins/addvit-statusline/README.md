# addvit-statusline

A rich, single-line statusline for Claude Code showing context usage, cumulative session tokens, and Claude.ai subscription rate-limits with a live countdown to reset.

## What it shows

```
Opus 4.7 │ ███░░░░░ 42% │ 425k/1000k │ sess:850k │ 5h:24% (2:33:05) 7d:41% (3d5h) │ ~/code/project │ (main)
```

| Segment | Meaning |
|---|---|
| `Opus 4.7` | Current model (the `Claude ` prefix is stripped) |
| `███░░░░░ 42%` | Context-window usage, colour-coded: cyan <50%, yellow ≥50%, red ≥80% |
| `425k/1000k` | Tokens used / context window size |
| `sess:850k` | Cumulative session input+output tokens |
| `5h:24% (2:33:05)` | Claude.ai subscription (Pro/Max) 5-hour rate-limit %. Parenthesised value = time remaining until the window resets |
| `7d:41% (3d5h)` | Same for the 7-day rate-limit window |
| `~/code/project` | Current working directory (with `~` substitution) |
| `(main)` | Git branch, if the cwd is a git repository |

Time format (designed so the countdown ticks live with `refreshInterval`):
- `≥ 1d` → `NdHh` (e.g. `3d5h` — seconds unnecessary for the 7d window)
- `< 1d, ≥ 1h` → `H:MM:SS` (e.g. `4:44:55` — typical 5h rate-limit display, ticks every second)
- `< 1h, ≥ 1m` → `MM:SS` (e.g. `40:26`)
- `< 1m` → `0:SS` (e.g. `0:42`)

> Rate-limit fields are only available to Claude.ai subscribers (Pro/Max) after the first API response in a session. Until then, that segment is simply hidden.

### Live countdown

For the countdown to tick every second (instead of only on Claude Code events like incoming messages — which don't fire while you're rate-limited), the installer sets `"refreshInterval": 2` inside `settings.json` → `statusLine`. That tells Claude Code to re-run the script every 2 seconds. You can tune the number (minimum `1`) if you want it smoother or cheaper.

## Install

### As a plugin (recommended)

Add the marketplace, then install:

```
/plugin marketplace add addvit-ru/addvit-statusline
/plugin install addvit-statusline@addvit-ru
```

Then ask Claude: *"установи statusline"* (or *"install statusline"*) — the bundled skill runs the installer pipeline, which copies the script to your Claude home and patches `settings.json`.

### Manual

```bash
cp skills/addvit-statusline/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 2
  }
}
```

Restart Claude Code (or start a new session).

## Requirements

- `bash` ≥ 4
- `jq` — JSON parser ([install](https://stedolan.github.io/jq))
- `awk` — ships with all \*nix systems and Git Bash
- `git` — optional, only for branch display
- On **Windows**: [Git for Windows](https://git-scm.com/download/win) (provides Git Bash) or WSL

## Uninstall

```
/plugin uninstall addvit-statusline@addvit-ru
```

Then remove `~/.claude/statusline-command.sh` and the `statusLine` key from `~/.claude/settings.json`.

## Privacy

The statusline script only reads the JSON that Claude Code pipes to it on stdin and echoes a formatted string — nothing is persisted, logged, or sent anywhere.

## License

MIT
