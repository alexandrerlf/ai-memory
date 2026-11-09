#!/bin/sh
# DeepSeek Harness (DSH) session-start hook, run by the official
# `@deepseek-ai/dsh-hooks-claude-code` bridge (Claude Code-shaped payload).
# Forwards the event JSON to the pitstop server, fire-and-forget.
#
# Capture only: DSH's bridge runs SessionStart detached, so its stdout
# cannot be relied on to deliver a fetched handoff. Fetching here would
# consume the baton (the server marks it accepted) and the result would
# most likely be dropped — so the handoff stays available on demand via
# the MCP `memory_handoff_accept` tool.
#
# Walks up from the payload's cwd for a .pitstop.toml marker file;
# if found, appends marker query params to the URL so the server
# applies the declared workspace/project/strategy instead of
# bucketing by basename(cwd) under the default workspace.
# At runtime (after `install-hooks --apply`) `_lib.sh` is staged
# alongside this script. From the source tree it lives one dir up.
_lib_dir="$(dirname "$0")"
[ -f "$_lib_dir/_lib.sh" ] || _lib_dir="$_lib_dir/.."
. "$_lib_dir/_lib.sh"

SERVER="${PITSTOP_HOOK_URL:-http://127.0.0.1:49374}"
PAYLOAD=$(cat)
CWD=$(pitstop_extract_cwd "$PAYLOAD")
QS=$(pitstop_marker_qs "$CWD")
SESSION_ID=$(pitstop_extract_session_id "$PAYLOAD")
SESSION_QS=""
[ -n "$SESSION_ID" ] && SESSION_QS="&session_id=$(pitstop_url_encode "$SESSION_ID")"

printf '%s' "$PAYLOAD" \
    | pitstop_post_hook "$SERVER/hook?event=session-start&agent=dsh${QS}${SESSION_QS}" >/dev/null 2>&1 || true
# Acknowledge with an empty JSON object so the bridge records a clean
# hook result (the run is detached, so nothing consumes this).
printf '{}\n'
exit 0
