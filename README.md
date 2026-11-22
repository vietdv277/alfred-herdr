# alfred-herdr

Alfred 6 workflow: see every Herdr app agent's status from anywhere on the Mac.

## Features

- [x] **Agent list**: an Alfred keyword lists Herdr agents, blocked first, refreshing while open;
  Enter jumps to the agent in Herdr.
- [ ] **Live panel**: an Alfred UI window that stays visible over any app and updates live.

## Usage

Type `hd` in Alfred to list every agent running in the Herdr app, blocked first, then working, done
and idle; sub-agents sit under their parent. Type more words to narrow the list — all of them must
match the name, agent, space/tab, folder or status.

Press <kbd>↩</kbd> to jump to the chosen agent: Herdr comes to the front, selects the agent's space
and tab and focuses its pane. An agent with no pane, such as a parked sub-agent, opens as a peek
instead. The list refreshes once a second while it is open.

## Requirements

- Alfred 6 with the Powerpack, macOS 12+.
- The Herdr desktop app with `hc` and `herdr-app` on this machine.

## Install (development)

```sh
bin/link    # symlinks workflow/ into Alfred's workflows folder
```
