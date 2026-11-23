# Shared agent model: the `terminal.list` reply normalised once for hd, hdp and later entry points.
# Loaded with `jq -L <workflow/lib>` and `include "agents";` so the caller derives the path
# from $0 and works from Alfred (cwd workflow/) as well as from panel.alfredui/scripts/.

# Agent logo name from Herdr's agent kind; an unknown kind gets the generic agent icon.
def logo: {"claude-code":"claude","claude":"claude","codex":"codex","opencode":"opencode",
           "kiro-cli":"kiro","kiro":"kiro","gemini":"gemini","antigravity":"antigravity",
           "agy":"antigravity"}[.] // "agent";

# <base>/<logo>-<status>.png, made by bin/make-icons. $base is "icons" for hd, the absolute
# icons directory for hdp; a missing or unknown status is "none".
def iconpath($base; $status): "\($base)/\(logo)-\(if ["blocked","working","done","idle"]
                                                       | index([$status]) then $status
                                                       else "none" end).png";

# Attention class: blocked, new (done or idle, unseen), working, done and seen, idle, then no status.
def attentionclass($unseen): if . == "blocked" then 0
  elif (. == "done" or . == "idle") and $unseen then 1
  elif . == "working" then 2
  elif . == "done" then 3
  elif . == "idle" then 4
  else 5 end;

# Sort key parts: the class, then the newest status change; an unknown change time sorts last.
def attentionkey: [.class, (if .status_ms == null then 0 else -.status_ms end)];

# Attention order for `to_entries` output; ties keep the feeder order in .key.
def attentionsort: sort_by([(.value | attentionkey[]), .key]);

# Live terminals that are agents: a finished terminal or a plain shell is not one.
def liveagent: select(.state == "live")
  | select((.agent // "?") | test("^(zsh|bash|sh|fish|nvim|vim)$") | not);

# "~" for the home directory itself and for paths under it.
def cwdshort($home): if . == $home then "~"
                     elif startswith($home + "/") then "~" + .[($home | length):]
                     else . end;

# Status as shown to the user; a missing or empty status reads "no status".
def statusword: if type == "string" and length > 0 then . else "no status" end;

# Compact age of a status change in ms relative to $now: "now", "Nm", "Nh", "Nd"; "" when unknown.
def age($now): if . == null then ""
  else ($now - .) as $ms
  | if $ms < 60000 then "now"
    elif $ms < 3600000 then "\((($ms / 60000) | floor))m"
    elif $ms < 86400000 then "\((($ms / 3600000) | floor))h"
    else "\((($ms / 86400000) | floor))d" end
  end;

# Status part of a subtitle: "new" for a finished turn not yet seen, the status with its age, then a
# working agent's current message.
def statusline($now):
  [(if .class == 1 then "new" else empty end),
   ((.status | statusword)
    + ((.status_ms | age($now)) as $a | if $a == "" then "" else " " + $a end)
    + (if .status == "working" and ((.msg // "") | length) > 0 then " · " + .msg else "" end))]
  | join(" · ");

# Every live agent as one record: the agent model plus cwd, turn, cwdshort, seen, unseen, class
# and msg. Feeder order; the caller filters and sorts. A turn that outran the `herdr.seen` label is
# unseen, and a missing label counts as 0, so an agent never drawn yet stays unseen.
def agentrecords($home):
  [.terminals[]
   | . + {agent: (.status.app // ((.argv[0] // "/?") | split("/") | last))}
   | liveagent
   | (.labels."herdr.seen" | if type == "number" then . elif type == "string" then (tonumber? // null) else null end) as $seen
   | (.turn // 0) as $turn
   | {address: .address, name: .name, agent: .agent, where: .labels.where,
      status: .status.state, msg: .status.msg, turn: $turn, cwd: (.cwd // ""),
      parent: .parent, state: .state, status_ms: .status_ms,
      seen: $seen,
      unseen: ($turn > ($seen // 0))} as $r
   | $r + {cwdshort: ($r.cwd | cwdshort($home)),
           class: ($r.status | attentionclass($r.unseen))}];

# One row as hd prints it, so hdn lands on the same title, subtitle and icon.
def hdrow($now):
  . as $r
  | {title: (($r.name // $r.agent) + " — " + ($r.where // "")),
     subtitle: (($r | statusline($now)) + " · " + $r.agent
                + " · turn " + ($r.turn | tostring) + " · " + $r.cwdshort
                + (if $r.parent then " · under " + $r.parent else "" end)),
     arg: $r.address,
     icon: {path: ($r.agent | iconpath("icons"; $r.status))},
     valid: true};

# The agents that need attention: blocked, then done or idle and unseen, in attention order.
# Working, done or idle and seen, and no-status agents never need it.
def attentionqueue($home):
  agentrecords($home) | map(select(.class <= 1)) | to_entries | attentionsort | map(.value);

# Terminals in the tab Herdr currently shows, sub-agents at any depth included; input is the
# `herdr-app ls` tree. An empty or unreadable tree yields [].
def currenttab:
  [.spaces[]? | select(.active == true) | .tabs[]? | select(.active == true)
   | .. | objects | .terminal? // empty] | unique;

# The queue minus every entry whose terminal is on screen, so a repeat press steps on.
def attentiontarget($tab): map(select(.address as $a | any($tab[]; . == $a) | not));
