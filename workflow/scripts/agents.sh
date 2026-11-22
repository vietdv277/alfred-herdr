#!/bin/zsh
# Alfred Script Filter: every agent in the Herdr app, attention first.
# Prints Alfred JSON; the optional $1 narrows the list, all words must match.
set -u

# Alfred runs scripts with a minimal PATH.
PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
hc_bin=${HC:-hc}
query=${1-}
lib=${0:A:h:h}/lib

# One invalid row, so Alfred says what went wrong instead of showing nothing.
fail() {
  jq -cn --arg title "$1" --arg sub "$2" '{items: [{title: $title, subtitle: $sub, valid: false}]}'
  exit 0
}

out=$("$hc_bin" ls --json 2>&1) ||
  fail "Herdr core is not running" "${out:-$hc_bin ls --json failed}"

json=$(jq -c -L "$lib" --arg q "$query" --arg home "$HOME" '
  include "agents";
  ($q | ascii_downcase | split(" ") | map(select(length > 0))) as $words
  | agentrecords($home)
  | map((. + {agent: (.agent // "?")}) as $r
      | {rank: ($r.status | rank),
         hay: ([($r.name // ""), $r.agent, ($r.where // ""), $r.cwd, ($r.status // "")]
               | map(ascii_downcase) | join(" ")),
         item: {title: (($r.name // $r.agent) + " — " + ($r.where // "")),
                subtitle: (($r.status | statusword) + " · " + $r.agent
                           + " · turn " + ($r.turn | tostring) + " · " + $r.cwdshort
                           + (if $r.parent then " · under " + $r.parent else "" end)),
                arg: $r.address,
                icon: {path: ($r.agent | iconpath("icons"; $r.status))},
                valid: true}})
  | to_entries
  | map(select(.value as $v | all($words[]; . as $w | ($v.hay | contains($w)))))
  | sort_by(.value.rank, .key)
  | map(.value.item) as $items
  | {rerun: 1,
     items: (if ($items | length) > 0 then $items
             else [{title: "No Herdr agents running",
                    subtitle: (if ($words | length) > 0
                               then "nothing matches " + $q
                               else "hc ls reports no live agents" end),
                    valid: false}]
             end)}' <<<"$out" 2>/dev/null) || fail "Herdr core is not running" "unexpected hc output: ${out:0:160}"

print -r -- "$json"
