#!/bin/zsh
# Alfred Script Filter: every agent in the Herdr app, attention first.
# Prints Alfred JSON; the optional $1 narrows the list, all words must match.
set -u

# Alfred runs scripts with a minimal PATH.
PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
hc_bin=${HC:-hc}
query=${1-}
lib=${0:A:h:h}/lib
# Age in subtitles is measured from here; a fixed value keeps tests deterministic.
now=${HERDR_NOW_MS:-$(( $(date +%s) * 1000 ))}
request='{"jsonrpc":"2.0","id":1,"method":"terminal.list","params":{}}'

# One invalid row, so Alfred says what went wrong instead of showing nothing.
fail() {
  jq -cn --arg title "$1" --arg sub "$2" '{items: [{title: $title, subtitle: $sub, valid: false}]}'
  exit 0
}

reply=$("$hc_bin" connect 2>&1 <<<$request) ||
  fail "Herdr core is not running" "${reply:-$hc_bin connect failed}"

# One JSON line per message; the reply to request id 1 carries the result.
result=$(print -r -- "$reply" | jq -cRn 'first(inputs | fromjson? | objects | select(.id == 1) | .result) // empty' 2>/dev/null) ||
  fail "Herdr core is not running" "unexpected hc connect output: ${reply:0:160}"
[[ -n $result ]] ||
  fail "Herdr core is not running" "${${reply:0:160}:-$hc_bin connect gave no reply}"

json=$(jq -c -L "$lib" --arg q "$query" --arg home "$HOME" --argjson now "$now" '
  include "agents";
  ($q | ascii_downcase | split(" ") | map(select(length > 0))) as $words
  | agentrecords($home)
  | map(. as $r
      | . + {hay: ([($r.name // ""), $r.agent, ($r.where // ""), $r.cwd, ($r.status // "")]
                  | map(ascii_downcase) | join(" ")),
             item: {title: (($r.name // $r.agent) + " — " + ($r.where // "")),
                    subtitle: (($r | statusline($now)) + " · " + $r.agent
                               + " · turn " + ($r.turn | tostring) + " · " + $r.cwdshort
                               + (if $r.parent then " · under " + $r.parent else "" end)),
                    arg: $r.address,
                    icon: {path: ($r.agent | iconpath("icons"; $r.status))},
                    valid: true}})
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
