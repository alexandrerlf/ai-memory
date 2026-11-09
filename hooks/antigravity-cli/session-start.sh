#!/bin/sh
# antigravity-cli SessionStart hook (and PreInvocation on installs from
# before SessionStart was wired). Forwards the event JSON to the pitstop
# server, then injects any pending handoff as a system message that stays in
# the conversation, using Antigravity's JSON stdout contract.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
# Only SessionStart omits invocationNum. A PreInvocation payload is a start
# boundary only at invocation zero; a later or malformed counter fails closed.
if printf '%s' "$PAYLOAD" | pitstop_after_key invocationNum >/dev/null \
    && ! pitstop_antigravity_is_initial_invocation "$PAYLOAD"; then
    printf '{}\n'
    exit 0
fi
CWD=$(pitstop_extract_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")
# The `[briefing]` opt-in rides the handoff GET, as in the native hook.
BRIEF_QS=$(pitstop_briefing_qs "$CWD")
SESSION_ID=$(pitstop_extract_session_id "$PAYLOAD")
# invocationNum restarts at 0 on every user turn: only a conversation's first
# start boundary may post session-start and claim a handoff.
if [ -n "$SESSION_ID" ]; then
    START_MARKER=$(pitstop_briefed_file "agy-start-$SESSION_ID")
    if [ -e "$START_MARKER" ]; then
        printf '{}\n'
        exit 0
    fi
    pitstop_mark_briefed "$START_MARKER"
fi
SESSION_QS=""
if [ -n "$SESSION_ID" ]; then
    SESSION_QS="&session_id=$(pitstop_url_encode "$SESSION_ID")"
fi

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=session-start&agent=antigravity-cli${QS}" >/dev/null 2>&1 || true
HANDOFF=$(pitstop_get_start_handoff "$PAYLOAD" "$SERVER/handoff?agent=antigravity-cli${QS}${SESSION_QS}${BRIEF_QS}" 2>/dev/null || true)
if [ -n "$HANDOFF" ]; then
    printf '{"injectSteps":[{"systemMessage":{"systemMessage":'
    printf '%s' "$HANDOFF" | pitstop_json_string
    printf '}}]}\n'
else
    printf '{}\n'
fi
exit 0
