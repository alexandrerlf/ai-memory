. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-start" -Agent "antigravity-cli" -FetchHandoff -AntigravityStartOutput
exit 0
