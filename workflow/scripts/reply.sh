#!/bin/zsh
# Alfred Script Filter for hdr: pick a Herdr agent, then type a follow-up prompt for it.
# `hdr <agent words> > <message>`; the words narrow agents exactly as hd does.
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

# The last 20 non-empty lines of an agent's screen, for the ⌘L preview; a failed read says so.
screen() {
  local out
  out=$("$hc_bin" read "$1" --json 2>/dev/null) || return 1
  print -r -- "$out" |
    jq -er '.text // "" | split("\n") | map(select(length > 0)) | .[-20:] | join("\n")' 2>/dev/null
}

hc_terminal_list || fail "Herdr core is not running" "$hc_error"

# The agent words come before the first " > ", the message after it; a trailing " >" is the same
# with nothing typed yet. Both stages keep the agent after the address it is reached on.
sel=$(jq -c -L "$lib" --arg q "$query" --arg home "$HOME" --argjson now "$now" '
  include "agents";
  def trimws: gsub("^[[:space:]]+|[[:space:]]+$"; "");
  ($q | split(" > ")) as $parts
  | (if ($parts | length) > 1 then {words: $parts[0], text: ($parts[1:] | join(" > "))}
     elif ($q | test(" >$")) then {words: ($q | .[:-2]), text: ""}
     else null end) as $stage
  | (if $stage == null then {words: $q, text: null} else $stage end) as $split
  | ($split.words | trimws) as $agentq
  | ($split.words | trimws | ascii_downcase | split(" ") | map(select(length > 0))) as $words
  | ($split.text | if . == null then "" else trimws end) as $text
  | agentrecords($home)
  | map(. as $r
      | . + {hay: ([($r.name // ""), $r.agent, ($r.where // ""), $r.cwd, ($r.status // "")]
                  | map(ascii_downcase) | join(" "))})
  | to_entries
  | map(select(.value as $v | all($words[]; . as $w | ($v.hay | contains($w)))))
  | attentionsort
  | map(.value) as $hits
  | if ($hits | length) == 0 then
      {items: [{title: "No Herdr agents running",
                subtitle: (if ($words | length) > 0 then "nothing matches " + $agentq
                           else "hc reports no live agents" end),
                valid: false}],
       addrs: []}
    elif $stage == null then
      {items: ($hits | map(replypick($now))), addrs: []}
    else
      ($hits | .[:5]) as $shown
      | {items: ($shown | map(. as $r | ($r | replyrow($now; $text)) + {_addr: $r.address})),
         addrs: ($shown | map(.address))}
    end' <<<"$result" 2>/dev/null) ||
  fail "Herdr core is not running" "unexpected terminal.list result: ${result:0:160}"

# Screens are read only for the rows shown, so a message stage costs at most five hc calls.
previews='{}'
for addr in ${(f)"$(print -r -- "$sel" | jq -r '.addrs[]?' 2>/dev/null)"}; do
  [[ -n $addr ]] || continue
  text=$(screen "$addr") || continue
  previews=$(jq -c --arg a "$addr" --arg t "$text" '. + {($a): $t}' <<<"$previews")
done

print -r -- "$sel" | jq -c --argjson previews "$previews" '
  {items: [.items[]
           | if has("_addr") then
               . as $i
               | del(._addr)
               | if ($previews | has($i._addr))
                 then . + {text: {copy: $previews[$i._addr], largetype: $previews[$i._addr]}}
                 else . end
             else . end]}'
