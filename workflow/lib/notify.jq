# Streaming alerts over `hc events --json`: one record per banner-worthy transition.
# Used as `jq -Rn --unbuffered -L <workflow/lib> --arg home "$HOME" 'include "agents";
# include "notify"; alerts(agentrecords($home))'`: every input line is one JSON object, and a line
# that is not JSON is ignored.
#
# `records` is the agent model from agents.jq, applied to the snapshot line. It arrives as a filter
# because jq 1.8 asserts when a module function calls another module's function that takes
# arguments, and including agents.jq here hits that on `agentrecords`.
#
# The first line is Herdr's snapshot: its agents are remembered with name, where, agent and
# status, and its non-agents (a plain shell, a finished terminal) stay mute, so their events never
# alert. A `status` event alerts when it moves a terminal into `blocked` or `done`, which is why a
# repeated `done` carrying only a new message stays quiet.

# What the watcher remembers per terminal.
def alertrecord: {name: .name, where: .where, agent: .agent, status: .status, msg: .msg};

# "name — where" for an agent the snapshot described, "agent — address" for one seen only in
# events, and no dangling separator when a part is missing.
def alerttitle($address):
  [(if .name != null or .where != null then (.name // .agent) else .agent end),
   (if .name != null or .where != null then .where else $address end)]
  | map(select(. != null and . != ""))
  | join(" — ");

# "done · claude-code · All tests pass", the message only when Herdr sent one.
def alertbody($state):
  [$state, .agent, .msg] | map(select(. != null and . != "")) | join(" · ");

# Alert records for the lines of `hc events --json`, nothing for everything else.
def alerts(records):
  foreach inputs as $line ({agents: {}, muted: [], out: null};
    .out = null
    | ($line | fromjson? // null) as $msg
    | if ($msg | type) == "object" and ($msg.terminals | type) == "array" then
        # Snapshot: replace the remembered state, so a reconnect never replays old transitions.
        (reduce ($msg | records)[] as $r ({}; .[$r.address] = ($r | alertrecord))) as $agents
        | .agents = $agents
        | .muted = [($msg.terminals[]).address | select(. as $a | $agents[$a] == null)]
      elif ($msg | type) == "object" and $msg.method == "event" and $msg.params.type == "status" then
        $msg.params.terminal as $address
        | $msg.params.data.status as $status
        | $status.state as $state
        | if (.muted | index($address)) != null then .
          else
            (.agents[$address]
             // {name: null, where: null, agent: ($status.app // "?"), status: null, msg: null}) as $was
            | .agents[$address] = ($was + {agent: ($was.agent // $status.app // "?"),
                                           status: ($state // $was.status),
                                           msg: $status.msg})
            | if ($state == "blocked" or $state == "done") and $state != $was.status then
                .agents[$address] as $now
                | .out = {address: $address, state: $state,
                          title: ($now | alerttitle($address)), body: ($now | alertbody($state))}
              else . end
          end
      else .
      end;
    if .out then .out else empty end);
