#!/bin/sh
# Devin CLI user-prompt hook.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
CWD=$(pitstop_resolve_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")
SID_QS=$(pitstop_session_id_qs devin user-prompt)

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=user-prompt&agent=devin${QS}${SID_QS}" >/dev/null 2>&1 || true
printf '{}\n'
exit 0
