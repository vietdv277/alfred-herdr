#!/bin/zsh
# Alfred Run Script for hdr ⌘↩: send the typed message to the Herdr agent at address $1.
# The text arrives in the reply_text variable, so quotes, $ and backticks reach hc intact.
set -u

# Alfred runs scripts with a minimal PATH.
PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
addr=${1-}
text=${reply_text-}
name=${reply_name:-$addr}
source "${0:A:h:h}/lib/hc.zsh"
source "${0:A:h:h}/lib/notify.zsh"

[[ -n $text ]] || { notify "Herdr Agents" "Nothing to send"; exit 0 }
[[ -n $addr ]] || { notify "Herdr Agents" "No agent address given"; exit 1 }

# No --force: hc refuses an agent that is not waiting for input, which is the point.
if out=$("$hc_bin" send "$addr" "$text" 2>&1); then
  notify "Sent to $name" "${text[1,80]}"
else
  notify "Not sent to $name" "${${out%%$'\n'*}:-$hc_bin send failed}"
  exit 1
fi
