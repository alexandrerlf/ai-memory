#!/bin/sh
# cursor SessionStart hook.
# 1. Forwards the event JSON to the pitstop server (fire-and-forget).
# 2. Synchronously fetches any pending cross-agent handoff and prints
#    it to stdout — agent CLIs prepend session-start hook stdout to
#    the next session, so the resuming agent sees prior context with
#    no human in the loop.
#
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
    | pitstop_post_hook "$SERVER/hook?event=session-start&agent=cursor${QS}" >/dev/null 2>&1 || true
pitstop_get_start_handoff "$PAYLOAD" "$SERVER/handoff?agent=cursor${QS}${SESSION_QS}${BRIEF_QS}" 2>/dev/null || true
exit 0
