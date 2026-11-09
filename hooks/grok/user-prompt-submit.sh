#!/bin/sh
# Grok Build CLI user-prompt hook.
# Do NOT fetch /handoff. Grok discards stdout of an allowing
# UserPromptSubmit (no additionalContext), and GET /handoff marks the
# handoff accepted. SessionStart must not fetch either. Recover with
# MCP memory_handoff_list then memory_handoff_accept.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
CWD=$(pitstop_extract_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=user-prompt&agent=grok${QS}" >/dev/null 2>&1 || true
printf '{}\n'
exit 0
