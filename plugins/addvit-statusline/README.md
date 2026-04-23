# addvit-statusline

A rich, single-line statusline for Claude Code that tracks context, rolling token windows, and API rate-limits with a live countdown to reset.

![example](https://placehold.co/800x60/111/0cf?text=Opus+4.7+%7C+%E2%96%88%E2%96%88%E2%96%88%E2%96%91%E2%96%91+42%25+%7C+425k%2F1000k+%7C+sess%3A850k+%7C+5h%3A24%25+%282h33m%29+7d%3A41%25+%283d5h%29)

## What it shows

```
Opus 4.7 │ ███░░░░░ 42% │ 425k/1000k │ sess:850k │ 5h:██░░░ · 24h:█████░ · 7d:████████ │ 5h:24% (2h33m) 7d:41% (3d5h) │ ~/code/project │ (main)
```

| Segment | Meaning |
|---|---|
| `Opus 4.7` | Current model (the `Claude ` prefix is stripped) |
| `███░░░░░ 42%` | Context-window usage, colour-coded: cyan <50%, yellow ≥50%, red ≥80% |
| `425k/1000k` | Tokens used / context window size |
| `sess:850k` | Cumulative session input+output tokens |
| `5h / 24h / 7d` bars | Rolling token spend over the last 5h / 24h / 7d, scaled to the 7d total. Data comes from a local JSONL log (`~/.claude/statusline-usage.jsonl`) that this script appends to on every render |
| `5h:24% (2h33m)` | Claude.ai subscription (Pro/Max) 5-hour rate-limit %. Parenthesised value = time remaining until the window resets |
| `7d:41% (3d5h)` | Same for the 7-day rolling rate-limit window |
| `~/code/project` | Current working directory (with `~` substitution) |
| `(main)` | Git branch, if the cwd is a git repository |

Time format: `>24h` → `NdHh`, `<24h` → `HhMMm`, `<1h` → `Mm`.

> Rate-limit fields are only available to Claude.ai subscribers (Pro/Max) after the first API response in a session. Until then, segment 6 is simply hidden.

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
    "command": "bash ~/.claude/statusline-command.sh"
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

Then remove `~/.claude/statusline-command.sh` and the `statusLine` key from `~/.claude/settings.json`. Optionally delete `~/.claude/statusline-usage.jsonl` (the rolling-window log).

## Privacy

The rolling-window log (`~/.claude/statusline-usage.jsonl`) records per-render events as `{ts, session_id, input_tokens, output_tokens}`. No prompts, tool calls, file paths, or other content are stored.

## License

MIT
