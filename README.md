# alfred-herdr

Alfred 6 workflow: see every Herdr app agent's status from anywhere on the Mac.

## Features

- [ ] **Agent list**: an Alfred keyword lists Herdr agents, blocked first, refreshing while open;
  Enter jumps to the agent in Herdr.
- [ ] **Live panel**: an Alfred UI window that stays visible over any app and updates live.

## Requirements

- Alfred 6 with the Powerpack, macOS 12+.
- The Herdr desktop app with `hc` and `herdr-app` on this machine.

## Install (development)

```sh
bin/link    # symlinks workflow/ into Alfred's workflows folder
```
