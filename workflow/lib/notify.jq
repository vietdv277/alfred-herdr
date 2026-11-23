# Alerts over `hc events --json`: one record per finished turn — into blocked or done, or `working`
# turning `idle` — and nothing for a repeated state, a heartbeat, a non-agent terminal or a garbled
# line. Started by workflow/scripts/watch.
#
# `records` is agents.jq's agent model, passed in as a filter because jq 1.8 aborts when a module
# function calls another module's function that takes arguments. `liveagent` is a leaf, so it is safe.
include "agents";

# A turn ending: a change into blocked or done, or the `idle` of an agent such as OpenCode that
# never reports `done`. `idle` from any other remembered status is not a turn ending.
def turnend($state; $was): (($state == "blocked" or $state == "done") and $state != $was)
                           or ($state == "idle" and $was == "working");

# "name — where" for a terminal the snapshot described, "agent — address" for one seen only in events.
def alerttitle($address):
  (if .name != null or .where != null then [.name // .agent, .where] else [.agent, $address] end)
  | map(select(. != null and . != ""))
  | join(" — ");

# "done · claude-code · All tests pass", the message only when Herdr sent one.
def alertbody($state):
  [$state, .agent, .msg] | map(select(. != null and . != "")) | join(" · ");

def alerts(records):
  foreach inputs as $line ({agents: {}, muted: [], out: null};
    .out = null
    | ($line | fromjson? // null) as $msg
    | if ($msg | type) == "object" and ($msg.terminals | type) == "array" then
        # Snapshot: live terminals are kept (a shell can start an agent later), the rest muted.
        ($msg | records) as $rows
        | (reduce $rows[] as $r ({}; .[$r.address] = $r.agent)) as $agentof
        | .agents = (reduce ($msg.terminals[] | select(.state == "live")) as $t ({};
                      .[$t.address] = {name: $t.name, where: $t.labels.where,
                                       agent: $agentof[$t.address], status: $t.status.state,
                                       msg: $t.status.msg}))
        | .muted = [($msg.terminals[] | select(.state != "live")).address]
      elif ($msg | type) == "object" and $msg.method == "event" and $msg.params.type == "status" then
        $msg.params.terminal as $address
        | $msg.params.data.status as $status
        | $status.state as $state
        | (.agents[$address]
           // {name: null, where: null, agent: null, status: null, msg: null}) as $was
        | ($status.app // $was.agent // "?") as $app
        | if (.muted | index($address)) != null then .
          elif ([({state: "live", agent: $app} | liveagent)] | length) == 0 then .
          else
            .agents[$address] = ($was + {agent: $app, status: ($state // $was.status),
                                         msg: $status.msg})
            | if turnend($state; $was.status) then
                .agents[$address] as $now
                | .out = {address: $address, state: $state,
                          title: ($now | alerttitle($address)), body: ($now | alertbody($state))}
              else . end
          end
      else .
      end;
    if .out then .out else empty end);
