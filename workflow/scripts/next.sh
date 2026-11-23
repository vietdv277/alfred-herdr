#!/bin/zsh
# Alfred entry point for hdn: the agent that most needs attention, as one row.
# `--jump` is the hotkey path: it focuses that agent straight away, with no list.
set -u

# Alfred runs scripts with a minimal PATH.
PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
app_bin=${HERDR_APP:-herdr-app}
here=${0:A:h}
lib=${here:h}/lib
focus_cmd=${FOCUS_CMD:-$here/focus.sh}
jump=0
[[ ${1-} == --jump ]] && jump=1
# Age in subtitles is measured from here; a fixed value keeps tests deterministic.
now=${HERDR_NOW_MS:-$(( $(date +%s) * 1000 ))}
source "$lib/hc.zsh"
source "$lib/notify.zsh"

# The core is down or its reply is unreadable: the row hd shows, or a banner for the hotkey.
core_down() {
  local sub=${1-}
  [[ -n $sub ]] || sub=${hc_error:-hc gave no reply}
  if (( jump )); then
    notify "Herdr Agents" "Herdr core is not running"
  else
    jq -cn --arg title "Herdr core is not running" --arg sub "$sub" \
      '{items: [{title: $title, subtitle: $sub, valid: false}]}'
  fi
  exit 0
}

hc_terminal_list || core_down

# The tab Herdr shows is what a repeated press steps past; no tree means no skipping.
ls_out=$("$app_bin" ls 2>/dev/null) || ls_out=

sel=$(jq -c -L "$lib" --arg ls "$ls_out" --arg home "$HOME" --argjson now "$now" '
  include "agents";
  ($ls | fromjson? // {}) as $app
  | attentionqueue($home) as $queue
  | ($queue | attentiontarget($app | currenttab)) as $rest
  | if ($rest | length) > 0 then
      ($rest[0] | hdrow($now)) as $row
      | (($rest | length) - 1) as $more
      | {target: $rest[0].address,
         items: [$row + {subtitle: ($row.subtitle
                                    + (if $more > 0 then " · +\($more) more" else "" end))}]}
    else
      {target: null,
       items: [{title: "Nothing needs attention",
                subtitle: (if ($queue | length) > 0 then "only the agents in this tab"
                           else "no blocked or new agents" end),
                valid: false}]}
    end' <<<"$result" 2>/dev/null) ||
  core_down "unexpected terminal.list result: ${result:0:160}"

if (( jump )); then
  addr=$(print -r -- "$sel" | jq -r '.target // empty' 2>/dev/null)
  if [[ -n $addr ]]; then
    "$focus_cmd" "$addr"
  else
    notify "Herdr Agents" "Nothing needs attention"
  fi
  exit 0
fi

print -r -- "$sel" | jq -c '{rerun: 1, items: .items}'
