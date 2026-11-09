#!/bin/sh
# Command Code SessionStart hook: capture the boundary, then inject a pending
# cross-agent handoff through hookSpecificOutput.additionalContext.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
CWD=$(pitstop_extract_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")
# The `[briefing]` opt-in rides the handoff GET, as in the native hook.
BRIEF_QS=$(pitstop_briefing_qs "$CWD")
SESSION_ID=$(pitstop_extract_session_id "$PAYLOAD")
SESSION_QS=""
[ -n "$SESSION_ID" ] && SESSION_QS="&session_id=$(pitstop_url_encode "$SESSION_ID")"

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=session-start&agent=command-code${QS}" >/dev/null 2>&1 || true

HANDOFF=$(pitstop_get_start_handoff "$PAYLOAD" "$SERVER/handoff?agent=command-code${QS}${SESSION_QS}${BRIEF_QS}" 2>/dev/null || true)
if [ -n "$HANDOFF" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
        "$(printf '%s' "$HANDOFF" | pitstop_json_string)"
else
    printf '{}\n'
fi
exit 0
