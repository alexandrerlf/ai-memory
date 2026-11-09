. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-start" -Agent "claude-code" -FetchHandoff -SessionStartEnvelope
exit 0
