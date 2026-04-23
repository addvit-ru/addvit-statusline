# addvit-ru — Claude Code plugin marketplace

A personal Claude Code marketplace by [@addvit-ru](https://github.com/addvit-ru) that currently hosts one plugin:

- **[addvit-statusline](plugins/addvit-statusline/)** — rich statusLine for Claude Code with live rate-limit countdowns.

## Install a plugin from this marketplace

In Claude Code:

```
/plugin marketplace add addvit-ru/addvit-statusline
/plugin install addvit-statusline@addvit-ru
```

(Replace `addvit-ru/addvit-statusline` with the actual GitHub `owner/repo` where this marketplace is published.)

## Repository layout

```
addvit-statusline/
├── .claude-plugin/
│   └── marketplace.json            # lists the plugins in this marketplace
└── plugins/
    └── addvit-statusline/
        ├── .claude-plugin/
        │   └── plugin.json         # plugin manifest
        ├── skills/
        │   └── addvit-statusline/
        │       ├── SKILL.md        # installer pipeline for Claude
        │       └── statusline-command.sh
        └── README.md
```

## Publishing

### 1. This marketplace (self-hosted)

```bash
cd C:/claude-home-1/addvit-statusline
git init
git add .
git commit -m "Initial commit: addvit-statusline plugin"
gh repo create addvit-ru/addvit-statusline --public --source=. --push
```

After push, anyone can install:
```
/plugin marketplace add addvit-ru/addvit-statusline
/plugin install addvit-statusline@addvit-ru
```

### 2. Submit to the official catalog (anthropics/claude-plugins-official)

Fork https://github.com/anthropics/claude-plugins-official, add the entry below into `.claude-plugin/marketplace.json` under `plugins[]`, and open a PR:

```json
{
  "name": "addvit-statusline",
  "description": "Rich statusLine: context bar, API rate-limits (5h/7d) with live countdown to reset (5h:24% (2:33:05)), cwd and git branch.",
  "category": "productivity",
  "author": { "name": "addvit-ru" },
  "source": {
    "source": "url",
    "url": "https://github.com/addvit-ru/addvit-statusline.git"
  },
  "homepage": "https://github.com/addvit-ru/addvit-statusline"
}
```

Once merged, users can install directly via:
```
/plugin install addvit-statusline@claude-plugins-official
```

## License

MIT
