# First PostToolUse of a Grok session: additionalContext is what the
# model actually sees. SessionStart and UserPromptSubmit must not fetch.
. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "grok" -FetchHandoff -GrokPostTool
exit 0
