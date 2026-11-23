# Shared `hc` access for hd and hdn: one terminal.list request over `hc connect`, and its reply
# parsed. Sourced after `set -u`; on failure hc_error says what went wrong and the caller decides
# how to report it.

hc_bin=${HC:-hc}
hc_request='{"jsonrpc":"2.0","id":1,"method":"terminal.list","params":{}}'

# Leaves the terminal.list result object in $result, or a reason in $hc_error and returns 1.
hc_terminal_list() {
  local reply
  command -v "$hc_bin" >/dev/null 2>&1 ||
    { hc_error="hc not found: install Herdr and open it once from Applications"; return 1 }
  reply=$("$hc_bin" connect 2>&1 <<<$hc_request) ||
    { hc_error=${reply:-$hc_bin connect failed}; return 1 }

  # One JSON line per message; the reply to request id 1 carries the result.
  result=$(print -r -- "$reply" | jq -cRn 'first(inputs | fromjson? | objects | select(.id == 1) | .result) // empty' 2>/dev/null) ||
    { hc_error="unexpected hc connect output: ${reply:0:160}"; return 1 }
  [[ -n $result ]] ||
    { hc_error="${${reply:0:160}:-$hc_bin connect gave no reply}"; return 1 }
  return 0
}
