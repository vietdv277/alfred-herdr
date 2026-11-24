# Security policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Report a vulnerability privately through
[GitHub's private vulnerability reporting](https://github.com/vietdv277/alfred-herdr/security/advisories/new),
not in a public issue or the Alfred Forum topic.

Include the release version, the macOS and Alfred versions, and the steps to reproduce. Reports are
answered on a best-effort basis; this is a personal project with no response-time commitment.

## Scope

The workflow runs locally and makes no network requests. It reads agent state through Herdr Core
(`hc`) and `herdr-app`, and sends follow-up prompts only when ⌘↩ is pressed in `hdr`. The security model is
described in [docs/architecture.md](docs/architecture.md#security-model). Issues in Herdr, Herdr
Core or Alfred themselves belong to those projects.
