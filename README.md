# alfred-herdr

Alfred 6 workflow: see every Herdr app agent's status from anywhere on the Mac.

## Features

- [x] **Agent list**: an Alfred keyword lists Herdr agents, blocked first, refreshing while open;
  Enter jumps to the agent in Herdr.
- [x] **Live panel**: an Alfred UI window that stays visible over any app and updates live.
- [x] **Notifier**: a macOS banner when an agent turns blocked or done, or ends a turn in `idle`,
  while Herdr is not in front.
- [x] **Quick reply**: a follow-up prompt sent to a finished agent without opening Herdr.

## Usage

Type `hd` in Alfred to list every agent running in the Herdr app in attention order: blocked, then
agents that finished a turn and have not been looked at yet (marked `new`; the status is `done`, or
`idle` for agents such as OpenCode that never report `done`), working, finished turns already seen,
and idle. Within a group the newest status change comes first, and the subtitle gives its age
(`done 3m`). Sub-agents sit under their parent. Type more words to narrow the list — all of them
must match the name, agent, space/tab, folder or status.

Press <kbd>↩</kbd> to jump to the chosen agent: Herdr comes to the front, selects the agent's space
and tab and focuses its pane. An agent with no pane, such as a parked sub-agent, opens as a peek
instead. The list refreshes once a second while it is open.

Type `hdp` to open a floating panel instead: a window listing the agents, refreshed every 2 s. It
stays above other apps, remembers its position between launches and closes with <kbd>⎋</kbd>.
Clicking a row jumps to that agent the same way <kbd>↩</kbd> does in `hd`.
The list scrolls when there are more agents than fit. The panel also opens from a script or another
workflow through the external trigger `panel`:

```sh
osascript -e 'tell application id "com.runningwithcrayons.Alfred" to run trigger "panel" in workflow "com.vietdv277.alfred-herdr"'
```

Type `hdn`, or press <kbd>↩</kbd> on its one row, to jump straight to the agent that most needs
attention: the newest blocked agent, or the newest agent that finished a turn and has not been seen
yet — status `done`, or `idle` for agents such as OpenCode that never report `done`. Agents
already on screen in the current Herdr tab are skipped while Herdr is in front, so pressing `hdn`
again steps to the next one. The workflow also carries an optional hotkey trigger for the same jump
without the list. It ships unassigned; set a key on it in Alfred (for example Hyper+N, ⌃⌥⇧⌘N).

Type `hdr` to send a follow-up prompt to an agent that has finished its turn, without opening Herdr:
pick the agent to get its `> ` prefix, then type the message after it. <kbd>⌘↩</kbd> sends the
message and <kbd>↩</kbd> only switches to that agent. A blocked agent takes no message; answer it in
Herdr first.

## Notifier

A background watcher posts one macOS banner the moment an agent turns `blocked` or `done`, or ends a
turn in `idle` as OpenCode does, while Herdr is not the front app, so a finished run or a pending
question is not missed from another window. Clicking the banner jumps to that agent, the same way
<kbd>↩</kbd> does in `hd`.
Transitions arriving together become a single banner naming the count, a status that only repeats
itself — another `done` carrying a new message — stays quiet, and nothing is posted while Herdr is
frontmost.

### One-time setup

The banner comes from a small helper app bundle, `Herdr Agents`, because macOS delivers
notifications only for a bundle started through LaunchServices. Its bundle id and signing identity
must stay stable: an ad-hoc signed or unsigned copy loses the permission, and macOS asks again.

1. Create a self-signed identity in the login keychain:

```sh
cd "$(mktemp -d)"
cat > herdr.cnf <<'EOF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = alfred-herdr local signing
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout key.pem -out cert.pem -config herdr.cnf
/usr/bin/openssl pkcs12 -export -in cert.pem -inkey key.pem -out identity.p12 -passout pass:
security import identity.p12 -k "$HOME/Library/Keychains/login.keychain-db" -P "" \
  -T /usr/bin/codesign
```

`/usr/bin/openssl` is the system LibreSSL; an identity built by Homebrew's OpenSSL 4 is rejected by
`codesign`. `security find-identity -v -p codesigning` should then list `alfred-herdr local signing`.

2. Build and sign the helper, then install the LaunchAgent that runs the watcher:

```sh
bin/build-notifier    # ~/Applications/Herdr Agents.app
bin/install-notifier  # ~/Library/LaunchAgents/com.vietdv277.alfred-herdr.watch.plist
```

`install-notifier` copies the watcher to `~/Library/Application Support/alfred-herdr` (override with
`NOTIFY_HOME`), because launchd cannot read a checkout under `~/Documents`. Re-run it after changing
`watch`, `focus.sh` or `workflow/lib`.

3. Allow notifications when macOS asks on the first banner. The permission sits under
`Herdr Agents` in System Settings › Notifications, and survives a rebuild under the same identity.

The watcher logs to `~/Library/Logs/alfred-herdr-watch.log`. `hd` and `hdp` stay the place to see
every agent at a glance; the banner interrupts only for a block or a
finished turn.

## Requirements

- Alfred 6 with the Powerpack, macOS 12+.
- The Herdr desktop app with `hc` and `herdr-app` on this machine.

## Install (development)

```sh
bin/link        # symlinks workflow/ into Alfred's workflows folder
bin/make-icons  # re-renders workflow/icons/ from assets/agents/*.svg (rsvg-convert, magick)
```

`bin/test` replays `tests/fixtures` through a fake `hc` and diffs `hd`, `hdp`, `hdn` and `hdr`
against `tests/expected/`; jq only, no Alfred or Herdr. The `hdr` send step is recorded through a
fake `hc send` and a fake banner, so the message argv is checked as it leaves Alfred. The notifier
cases replay a fixed `hc events` stream from `tests/fixtures/events-*.jsonl` through a fake notify
that records the banner arguments, and `swiftc -typecheck` covers the helper when Swift is
installed.

The agent logos in `assets/agents/` are the ones the Herdr app shows; each `hd` row combines its
agent's logo with a status dot. An agent without a logo gets the generic `agent` icon.
