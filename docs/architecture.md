# Architecture

How the workflow turns Herdr's agent state into Alfred rows, a panel and banners. The plan and its
phases are in [roadmap.md](roadmap.md); decisions are logged in the pinned roadmap issue #12.

## Components

```
              Herdr app ── hc (Herdr Core, ~/.local/bin) ── the only source of truth
                │ terminal.list (snapshot)          │ hc events (stream)
                ▼                                   ▼
   workflow/lib/hc.zsh  hc_terminal_list     workflow/scripts/watch
                │                                   │
                ▼                                   ▼
   workflow/lib/agents.jq                    workflow/lib/notify.jq
   agent model: records → attention class   turn ends, alert title/body
   → sort → rows, queue, reply picks         (uses agents.jq records)
                │                                   │
   ┌────────────┼──────────────┬──────────┐         ▼
   ▼            ▼              ▼          ▼   workflow/lib/notify.zsh
 agents.sh    next.sh       reply.sh   panel.alfredui   → Herdr Agents.app banner
 hda list     hdn / hotkey  hdr        pulse (2 s)       (notifier/, Swift)
   └────────────┴──────┬───────┴──────────┘                 │ click
                       ▼                                    │
             workflow/scripts/focus.sh  ◀───────────────────┘
             space → tab → pane (the one jump path)
                       send.sh: hdr ⌘↩ → hc send
```

- **One agent model.** `agents.jq` defines records, the attention class and the sort once;
  `hda`, `hdn`, `hdr`, the panel and the notifier all use it.
- **One jump path.** Every entry point ends in `scripts/focus.sh`.
- **Stateless.** Unseen means `turn > herdr.seen`, read from Herdr each time; no local state file.
- **Nothing duplicated from the Herdr app.**

## Entry points

| Entry | Script | Trigger |
|---|---|---|
| `hda` | `scripts/agents.sh` | Script Filter, reruns every second while open |
| `hdn` | `scripts/next.sh` (`--jump` for the hotkey) | Script Filter or an unassigned hotkey |
| `hdr` | `scripts/reply.sh`, then `scripts/send.sh` on ⌘↩ | Script Filter |
| `hdp` | `panel.alfredui` (`ui.json`, `scripts/pulse`, `scripts/focus`) | Alfred UI object, external trigger `panel` |
| Notifier | `scripts/watch` under a LaunchAgent, `notifier/HerdrNotify.swift` | `hc events`, optional, from a source checkout |

## Security model

- **No network requests and no credentials.** The workflow talks only to the local `hc` and
  `herdr-app`.
- **Sending text is explicit.** Only ⌘↩ in `hdr` sends a prompt; the text travels in the
  `reply_text` variable, so quotes, `$` and backticks reach `hc send` intact, never through a shell
  string.
- **Notifier signing.** The helper app is signed with a local self-signed identity so the
  notification permission stays bound to it; the LaunchAgent runs a copy under
  `~/Library/Application Support/alfred-herdr`, not the checkout.
- **Packaging from git.** `bin/package` builds from the committed tree, so a locally assigned hotkey
  or any uncommitted change never ships.
- **Fixtures are fictional.** Tests replay recorded `hc` output with made-up agent names and paths.

## Testing

`bin/test` replays `tests/fixtures` through a fake `hc` (`tests/fake-hc`, `fake-herdr-app`,
`fake-focus`, `fake-notify`) and diffs every entry point against `tests/expected/`; no Alfred, no
Herdr, no network. `swiftc -typecheck` covers the helper when Swift is installed. A behaviour
change comes with a case that fails without it.
