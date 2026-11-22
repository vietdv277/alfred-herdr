# Roadmap

Agreed 2026-11-23. Progress and decisions are tracked in the pinned issue #12.

## Jobs

1. Switch to any Herdr agent while working outside the Herdr app.
2. Jump quickly to an agent that needs attention: finished, blocked, waiting.

A feature earns its place by shortening one of these paths.

## Gaps

- A fresh "done" looks the same as an old one, so new finishes get lost among stale rows.
- Nothing signals a change while Herdr is in the background; `hd` and `hdp` only help once opened.

## Architecture

```
            hc ls --json  (Herdr is the only source of truth)
                     │
            ┌────────▼────────┐
            │  agent model    │  shared jq module:
            │                 │  normalise → attention class → rank → icon
            └────────┬────────┘
   ┌─────────┬───────┼──────────┬──────────────┐
   ▼         ▼       ▼          ▼              ▼
  hd        hdn     hdp      notifier      quick reply
 search    jump    panel     push on       (later)
 & pick    to #1   ambient   change
   └─────────┴───────┴─────────┴──────────────┘
                     ▼
               scripts/focus   (the one jump path)
```

- One agent model, many entry points; no jq helpers duplicated between scripts.
- "Needs attention" is defined once and drives ranking everywhere.
- Stateless where possible: prefer Herdr's own `status_ms` / `herdr.seen` over a local state file.
- Nothing that duplicates the Herdr app's own features.

## Phases

Order: 0 → 1 → 3 → 2, with 4 decided when the panel trial gives an answer.

| Phase | Issue | Goal |
|---|---|---|
| 0 | #5 (spike, decision) | Learn what Herdr exposes: seen/timestamp semantics, waiting status, change stream, app notifications |
| 0 | #6 | Shared agent model and fixture tests |
| 1 | #7 | Attention ranking: unseen first, recency, age in subtitle |
| 3 | #8 (decision) | Notification on blocked/done while Herdr is in the background |
| 2 | #9 | `hdn`: jump straight to the most urgent agent |
| 4 | #10 (decision) | Keep, narrow or remove `hdp` |
| later | #11 | Quick reply to an agent from Alfred |

Issues labelled `decision` record the outcome as a comment, summarised in the decisions log of #12.
