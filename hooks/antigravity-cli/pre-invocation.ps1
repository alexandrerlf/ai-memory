. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-start" -Agent "antigravity-cli" -FetchHandoff -AntigravityStartOutput -AntigravityPreInvocation
exit 0
