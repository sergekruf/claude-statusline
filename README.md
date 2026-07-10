# Claude Code statusline

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Works with Claude Code](https://img.shields.io/badge/Claude%20Code-statusLine-cc785c?logo=claude&logoColor=white)](https://claude.com/claude-code)
![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)

A richer status line for [Claude Code](https://claude.com/claude-code) — shows what the built-in bar leaves out.

![statusline panel](panel.svg)

```
ctx:41k/1000k(4%) │ 5h:13% 7d:2% │ Opus 4.8 ·xhigh │ cost:$0.41 │ +12/-3 │ v2.1.197↑2.1.206 │ main:agents
```

## Segments

| Segment | Meaning | Source field |
|---|---|---|
| `ctx:41k/1000k(4%)` | Context fill: tokens in context / window size / percent. Turns yellow ≥60%, red ≥80%. | `context_window.total_input_tokens`, `.context_window_size`, `.used_percentage` |
| `5h:13% 7d:2%` | Rate-limit usage for the 5-hour and 7-day windows | `rate_limits.five_hour` / `.seven_day` |
| `Opus 4.8 ·xhigh` | Model family + version, and the reasoning effort level | `model.id`, `effort.level` |
| `cost:$0.41` | Session cost so far (USD) | `cost.total_cost_usd` |
| `+12/-3` | Lines added / removed this session | `cost.total_lines_added` / `.total_lines_removed` |
| `v2.1.197↑2.1.206` | Claude Code version. Dim when current; turns yellow with `↑<latest>` when a newer version is on npm. | `version` + npm registry |
| `main:agents` | git branch : working-directory name | `git` + `workspace.current_dir` |

> Note: `context_window.total_input_tokens` is the real context fill. `current_usage.input_tokens` is only the *marginal* input of the last request (the rest sits in cache) — using it makes the token count read `0k`, which is the bug this script exists to avoid.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sergekruf/claude-statusline/main/install.sh | bash
```

This downloads the script to `~/.claude/statusline-command.sh` and points `statusLine` in `~/.claude/settings.json` at it. Set `CLAUDE_CONFIG_DIR` first if your config lives elsewhere.

### Manual install

```bash
curl -fsSL https://raw.githubusercontent.com/sergekruf/claude-statusline/main/statusline-command.sh -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
}
```

## Dependencies

- `jq` — required (parses the status JSON)
- `bc` — optional, for the cost segment
- `git` — optional, for the branch segment
- `curl` — optional, for the Claude Code update check

The panel re-renders every turn, so changes to the script take effect with no restart.

### Update check

The version segment compares your Claude Code version against the latest on the npm
registry. The lookup runs **in the background at most once every 6 hours** and is cached to
`${XDG_CACHE_HOME:-~/.cache}/claude-statusline/latest-version` — rendering only ever reads the
cache, so the panel never blocks on the network.

## License

[MIT](LICENSE)
