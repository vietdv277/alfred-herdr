#!/bin/zsh
# Alfred Script Filter: every agent in the Herdr app, attention first.
# Prints Alfred JSON; the optional $1 narrows the list, all words must match.
set -u

# Alfred runs scripts with a minimal PATH.
PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
query=${1-}
lib=${0:A:h:h}/lib
# Age in subtitles is measured from here; a fixed value keeps tests deterministic.
now=${HERDR_NOW_MS:-$(( $(date +%s) * 1000 ))}
source "$lib/hc.zsh"

# One invalid row, so Alfred says what went wrong instead of showing nothing.
fail() {
  jq -cn --arg title "$1" --arg sub "$2" '{items: [{title: $title, subtitle: $sub, valid: false}]}'
  exit 0
}

hc_terminal_list || fail "Herdr core is not running" "$hc_error"

json=$(jq -c -L "$lib" --arg q "$query" --arg home "$HOME" --argjson now "$now" '
  include "agents";
  ($q | ascii_downcase | split(" ") | map(select(length > 0))) as $words
  | agentrecords($home)
  | map(. as $r
      | . + {hay: ([($r.name // ""), $r.agent, ($r.where // ""), $r.cwd, ($r.status // "")]
                  | map(ascii_downcase) | join(" ")),
             item: hdrow($now)})
  | to_entries
  | map(select(.value as $v | all($words[]; . as $w | ($v.hay | contains($w)))))
  | attentionsort
  | map(.value.item) as $items
  | {rerun: 1,
     items: (if ($items | length) > 0 then $items
             else [{title: "No Herdr agents running",
                    subtitle: (if ($words | length) > 0
                               then "nothing matches " + $q
                               else "hc reports no live agents" end),
                    valid: false}]
             end)}' <<<"$result" 2>/dev/null) ||
  fail "Herdr core is not running" "unexpected terminal.list result: ${result:0:160}"

print -r -- "$json"
