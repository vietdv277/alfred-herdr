#!/bin/zsh
# Alfred Run Script: bring the Herdr agent at address $1 to the front.
# Walks space, then tab, then pane: since Herdr 0.9 focus alone leaves the window put.
set -u

# Alfred runs scripts with a minimal PATH.
PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
app_bin=${HERDR_APP:-herdr-app}
addr=${1-}

notify() {
  osascript -e 'on run argv' \
    -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
    -e 'end run' "${1:-Herdr Agents}" "${2:-}" >/dev/null 2>&1 || true
}

[[ -n $addr ]] || { notify "Herdr Agents" "No agent address given"; exit 1 }

open -a Herdr

# The app answers once its window is up; give it a moment to come back.
ls_out=
for _ in {1..30}; do
  ls_out=$("$app_bin" ls 2>/dev/null) && [[ -n $ls_out ]] && break
  sleep 0.1
done
[[ -n $ls_out ]] || { notify "Herdr Agents" "Herdr is not running"; exit 1 }

# Space and tab ids come from the app's own tree; hc labels miss the tab for some terminals.
ids=$(print -r -- "$ls_out" | jq -r --arg t "$addr" '
  first(.spaces[] as $s | $s.tabs[] as $b
    | select([$b | .. | objects | select(.terminal? == $t)] | length > 0)
    | [$s.id, $b.id] | @tsv) // empty' 2>/dev/null)

if [[ -n $ids ]]; then
  space=${ids%%$'\t'*}
  tab=${ids##*$'\t'}
  [[ -z ${space// } ]] || "$app_bin" do space.select --id "$space" >/dev/null 2>&1
  [[ -z ${tab// } ]] || "$app_bin" do tab.select --id "$tab" >/dev/null 2>&1
  if ! out=$("$app_bin" do pane.focus --terminal "$addr" 2>&1); then
    notify "Herdr Agents" "${out:-pane.focus failed for $addr}"
    exit 1
  fi
else
  # A parked sub-agent has no pane: peek over the tab instead.
  if ! out=$("$app_bin" do terminal.peek --terminal "$addr" 2>&1); then
    notify "Herdr Agents" "Agent $addr has no pane in Herdr"
    exit 1
  fi
fi
