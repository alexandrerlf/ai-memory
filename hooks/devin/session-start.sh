#!/bin/sh
# Devin CLI SessionStart hook.
# 1. Forwards the event JSON to pitstop.
# 2. Synchronously fetches the pending handoff and injects it through
#    hookSpecificOutput.additionalContext, which Devin consumes as
#    additional session context.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
CWD=$(pitstop_resolve_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")
# The `[briefing]` opt-in rides the handoff GET, as in the native hook.
BRIEF_QS=$(pitstop_briefing_qs "$CWD")
SID_QS=$(pitstop_session_id_qs devin session-start)

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=session-start&agent=devin${QS}${SID_QS}" >/dev/null 2>&1 || true

HANDOFF=$(pitstop_get_start_handoff "$PAYLOAD" "$SERVER/handoff?agent=devin${QS}${SID_QS}${BRIEF_QS}" 2>/dev/null || true)
if [ -n "$HANDOFF" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
        "$(printf '%s' "$HANDOFF" | pitstop_json_string)"
else
    printf '{}\n'
fi
exit 0
