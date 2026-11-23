# Shared macOS notifications: focus.sh reports what it could not do, next.sh says when there is
# nothing to jump to. NOTIFY_SHOW_CMD replaces osascript in tests; it is called as <cmd> <title>
# <message>.

notify() {
  local title=${1:-Herdr Agents} msg=${2:-}
  if [[ -n ${NOTIFY_SHOW_CMD:-} ]]; then
    "$NOTIFY_SHOW_CMD" "$title" "$msg" >/dev/null 2>&1 || true
    return
  fi
  osascript -e 'on run argv' \
    -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
    -e 'end run' "$title" "$msg" >/dev/null 2>&1 || true
}
