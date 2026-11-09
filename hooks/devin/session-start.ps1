. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-start" -Agent "devin" -FetchHandoff -SessionStartEnvelope
exit 0
