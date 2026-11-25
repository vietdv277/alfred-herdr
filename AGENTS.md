# AGENTS.md

Alfred 6 workflow showing the status of every agent running in the Herdr desktop app (GUI), from
anywhere on the machine. Shared context for all Alfred workflows lives in the hub,
`~/Documents/workspaces/ken/alfred-6-workflows`; verified Alfred 6 notes live in the
`alfred-workflow` skill (`~/dotfiles/common/.claude/skills/alfred-workflow/`).

## Layout

- `workflow/` is the Alfred workflow bundle (`info.plist`, `icon.png`, scripts, `*.alfredui`).
  `bin/link` symlinks it into Alfred's workflows folder, so edits are live in Alfred.
- `bin/` holds dev helpers. Nothing in `bin/` ships in the workflow.

## Data source

- `hc ls --json` lists every Herdr terminal and works from any process, not only inside Herdr.
  Rows: `address`, `agent` (`claude-code`, `kiro-cli`, `opencode`, `zsh`, ...), `status`
  (`working` | `blocked` | `done` | `idle` | absent), `where` ("Space / tab"), `cwd`, `turn`,
  `name`, `parent` (a sub-agent's leader address). Shells (`zsh`, `bash`) and editors are not agents.
- `hc events --json` streams changes as JSON lines.
- `herdr-app do pane.focus` focuses the pane showing a terminal; `herdr-app commands` lists every
  command with its arguments.
- Alfred runs scripts with a minimal `PATH`: call `hc`, `herdr-app` and `jq` by absolute path or
  prepend `$HOME/.local/bin:/opt/homebrew/bin` in the script.

## Reference workflows

Alfred's own Alfred UI examples are installed and are the ground truth for `info.plist` object
types and `ui.json`:
`~/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows/` — Launchpad
(`launchpad.alfredui`) and Try Alfred UI (`try.alfredui`). Read them; never edit them.

## Git

- Conventional commits (`feat: ...`, `fix: ...`), one line.
- Work on a feature branch; never commit on `main`, never push. The leader pushes and opens PRs;
  the user merges.
