#!/bin/sh
# cursor stop hook.
# Forwards the event JSON to the pitstop server, fire-and-forget.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
CWD=$(pitstop_extract_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=stop&agent=cursor${QS}" >/dev/null 2>&1 || true
exit 0
