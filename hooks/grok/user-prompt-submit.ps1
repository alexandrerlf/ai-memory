# Do not fetch /handoff. Grok discards allowing UserPromptSubmit stdout,
# and GET /handoff would accept the handoff anyway.
. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "user-prompt" -Agent "grok"
exit 0
