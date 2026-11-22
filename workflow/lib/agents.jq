# Shared agent model: `hc ls --json` normalised once for hd, hdp and later entry points.
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

# Attention order: blocked, working, done, idle, then anything else.
def rank: if . == "blocked" then 0 elif . == "working" then 1
          elif . == "done" then 2 elif . == "idle" then 3 else 4 end;

# Live terminals that are agents: a finished terminal or a plain shell is not one.
def liveagent: select(.state == "live")
  | select((.agent // "?") | test("^(zsh|bash|sh|fish|nvim|vim)$") | not);

# "~" for the home directory itself and for paths under it.
def cwdshort($home): if . == $home then "~"
                     elif startswith($home + "/") then "~" + .[($home | length):]
                     else . end;

# Status as shown to the user; a missing or empty status reads "no status".
def statusword: if type == "string" and length > 0 then . else "no status" end;

# Every live agent as one record: the raw hc fields plus cwd, turn and cwdshort.
# Feeder order; the caller ranks and sorts. Raw fields stay raw so each entry point can
# keep its own display defaults.
def agentrecords($home):
  [.terminals[] | liveagent
   | . + {cwd: (.cwd // ""), turn: (.turn // 0),
          cwdshort: ((.cwd // "") | cwdshort($home))}];
