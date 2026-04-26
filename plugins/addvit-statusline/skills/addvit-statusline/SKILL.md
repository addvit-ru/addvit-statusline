---
name: addvit-statusline
description: Установить продвинутый statusLine для Claude Code. Показывает предупреждение «plan new session» при контексте ≥75% и «NEW SESSION» при ≥90%, имя модели, прогресс-бар контекстного окна с процентом, use/total в токенах, кумулятивные session-токены, API rate-limits 5h/7d с цветным процентом и обратным отсчётом до сброса окна в формате "5h:24% (2:33:05)" и "7d:41% (3d5h)". Плюс cwd и git-ветка. Используй когда пользователь просит "установить statusline", "поставить красивый статусбар", "хочу такой же statusline", "statusline с rate-limits", "statusline с countdown", "statusline с предупреждением о новой сессии", или когда переносит этот skill в новое окружение и нужно его активировать. Работает на macOS/Linux из коробки, на Windows требует Git Bash (идёт с Git for Windows) или WSL.
---

# addvit-statusline

Установщик кастомного statusLine для Claude Code. Скрипт уже лежит рядом с этим SKILL.md (`statusline-command.sh`). Задача скилла — аккуратно положить его в claude-home пользователя и прописать в `settings.json`.

## Что показывает statusLine

Пример строки (разделитель `│`, цвета ANSI):

```
⚠ plan new session │ Opus 4.7 │ ctx: ██████░░ 78% │ 785k/1000k │ sess:850k │ 5h:24% (2:33:05) 7d:41% (3d5h) │ D:/project │ (main)
```

Сегменты слева направо:

| # | Что | Источник |
|---|---|---|
| 0 | Предупреждение о приближении к лимиту контекста: `⚠ plan new session` (bold red) при ≥75%, `⚠ NEW SESSION` (white-on-red) при ≥90%. Скрыт ниже 75%. | `context_window.used_percentage` |
| 1 | Модель | `model.display_name` (префикс `Claude ` срезается) |
| 2 | Префикс `ctx:` + бар + % контекст-окна, цвет по порогам (cyan <50, yellow ≥50, red ≥80) | `context_window.used_percentage` |
| 3 | Использовано/всего токенов (current_usage.in+out / context_window_size) | `context_window.*` |
| 4 | `sess:NNk` — кумулятивные session-токены | `context_window.total_input_tokens + total_output_tokens` |
| 5 | API rate-limits: `5h:XX% (H:MM:SS)` и `7d:YY% (NdHh)` — процент использования + оставшееся время до сброса окна | `rate_limits.five_hour.*`, `rate_limits.seven_day.*` (только Pro/Max после первого ответа API) |
| 6 | Cwd (с подстановкой `~`) | `cwd` |
| 7 | Git-ветка в скобках, если директория — git-репозиторий | `git symbolic-ref` |

Форматирование оставшегося времени (секция 5):
- `≥1d` → `NdHh` (например `3d5h` — для 7d-окна секунды не нужны)
- `<1d, ≥1h` → `H:MM:SS` (например `4:44:55` — живой тикер)
- `<1h, ≥1m` → `MM:SS` (например `40:26`)
- `<1m` → `0:SS` (например `0:42`)
- `≤0` → пусто (окно сброшено, API ещё не обновил `resets_at`) — сегмент `(...)` целиком скрывается

`resets_at` принимается в двух форматах: Unix epoch (число) или ISO-8601 строка. Скрипт авто-определяет и нормализует через GNU `date -d`.

Rate-limits появляются **только** для Claude.ai подписчиков (Pro/Max) после первого ответа API в сессии. До этого их просто нет в JSON — сегмент 5 скрывается автоматически.

## Когда триггерить скилл

Пользователь хочет установить этот statusLine у себя. Фразы: «установи statusline», «хочу такой же статусбар», «поставь statusline с rate-limits и countdown», «перенеси этот statusline на другой комп». Если пользователь приносит этот skill в новое окружение и говорит «активируй» — тоже триггер.

## Требования

- `bash` ≥ 4 (macOS через Homebrew или Git Bash/WSL на Windows)
- `jq` (парсер JSON) — https://stedolan.github.io/jq
- `awk` — есть по умолчанию в \*nix и Git Bash
- `git` — опционально, только для отображения ветки

На Windows путь к bash внутри Claude Code задаётся как `bash` — обычно это Git Bash, входящий в Git for Windows. Если его нет — установить Git for Windows.

## Pipeline установки

### Шаг 1 — определить claude-home пользователя

По порядку:
1. Если в окружении задан `CLAUDE_CONFIG_DIR` — использовать его
2. Иначе macOS/Linux: `$HOME/.claude`
3. Иначе Windows: `$USERPROFILE/.claude` (в bash это `$HOME/.claude` тоже работает)

Сразу проверить, что директория существует (Claude Code должен был её создать). Если нет — сказать пользователю запустить Claude Code один раз, чтобы она появилась.

### Шаг 2 — скопировать скрипт

Скрипт лежит рядом с этим SKILL.md — `./statusline-command.sh`. Если скилл загружен как часть плагина, его корень доступен через переменную `$CLAUDE_PLUGIN_ROOT`; иначе используй абсолютный путь каталога SKILL.md.

```bash
# Внутри плагина:
SKILL_DIR="${CLAUDE_PLUGIN_ROOT:-}/skills/addvit-statusline"
# Fallback (ручная установка без плагина):
[ -z "$CLAUDE_PLUGIN_ROOT" ] && SKILL_DIR="<абсолютный путь к каталогу этого SKILL.md>"

CLAUDE_HOME="<определено на шаге 1>"

cp "$SKILL_DIR/statusline-command.sh" "$CLAUDE_HOME/statusline-command.sh"
chmod +x "$CLAUDE_HOME/statusline-command.sh"
```

На Windows `chmod +x` безвреден (no-op для NTFS без WSL) — оставить.

Если `$CLAUDE_HOME/statusline-command.sh` уже существует и отличается — сначала забэкапить:
```bash
[ -f "$CLAUDE_HOME/statusline-command.sh" ] && \
  cp "$CLAUDE_HOME/statusline-command.sh" "$CLAUDE_HOME/statusline-command.sh.bak.$(date +%s)"
```

### Шаг 3 — пропатчить settings.json

Читать `$CLAUDE_HOME/settings.json`. Если файла нет — создать минимальный:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash <CLAUDE_HOME>/statusline-command.sh",
    "refreshInterval": 2
  }
}
```

Ключ `refreshInterval: 2` **обязателен** — без него счётчик rate-limit замирает между событиями (и особенно когда упёрся в лимит, запросы не идут и statusLine не пересчитывается). С `refreshInterval: 2` Claude Code пересобирает строку каждые 2 секунды, счётчик тикает вживую. Минимальное значение — 1, но 2 — хороший компромисс по нагрузке.

Если файл есть — **сначала сделать backup** (`settings.json.bak.<epoch>`), затем через `jq` добавить/заменить ключ `statusLine`:
```bash
jq --arg cmd "bash $CLAUDE_HOME/statusline-command.sh" \
   '.statusLine = {"type":"command", "command":$cmd, "refreshInterval":2}' \
   "$CLAUDE_HOME/settings.json" > "$CLAUDE_HOME/settings.json.tmp" \
   && mv "$CLAUDE_HOME/settings.json.tmp" "$CLAUDE_HOME/settings.json"
```

Не трогать остальные ключи (`permissions`, `hooks`, `voice` и пр.).

### Шаг 4 — smoke-тест

Скормить скрипту синтетический JSON и убедиться, что он выдал не пустую строку и не ругнулся:

```bash
NOW=$(date +%s); RESET5=$(( NOW + 9240 )); RESET7=$(( NOW + 280000 ))
echo "{\"session_id\":\"t\",\"cwd\":\"$HOME\",\"model\":{\"display_name\":\"Opus 4.7\"},\"context_window\":{\"used_percentage\":42.5,\"context_window_size\":1000000,\"current_usage\":{\"input_tokens\":400000,\"output_tokens\":25000},\"total_input_tokens\":800000,\"total_output_tokens\":50000},\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":$RESET5},\"seven_day\":{\"used_percentage\":41.2,\"resets_at\":$RESET7}}}" \
| bash "$CLAUDE_HOME/statusline-command.sh"
```

Ожидаемый вывод должен содержать `Opus 4.7`, `5h:24% (2:33:05)`, `7d:41% (3d5h)`.

### Шаг 5 — отчитаться пользователю

Коротко вернуть:
- куда скопирован скрипт
- что прописано в `settings.json.statusLine`
- путь к бэкапу settings (если был)
- напомнить: **перезапусти Claude Code** или открой новую сессию, чтобы statusLine подхватился

## Удаление (если попросят)

1. Из `settings.json` удалить ключ `statusLine` (через jq `del(.statusLine)`)
2. Удалить `$CLAUDE_HOME/statusline-command.sh`
3. По желанию — `$CLAUDE_HOME/statusline-usage.jsonl` (лог rolling-окон)

## Что скилл НЕ делает

- Не пишет секреты в логи (лог содержит только счётчики токенов и session_id)
- Не редактирует глобальные env-переменные пользователя
- Не трогает `.bashrc`/`.zshrc`
- Не устанавливает зависимости (`jq`, `git`) — только проверяет их наличие и просит поставить, если чего-то не хватает

## Как передать другим

Всю папку `addvit-statusline/` (SKILL.md + statusline-command.sh) — запаковать/отправить/закоммитить. Получатель кладёт её в `~/.claude/skills/addvit-statusline/` (macOS/Linux) или `%USERPROFILE%\.claude\skills\addvit-statusline\` (Windows) и просит Claude Code: «установи statusline».
