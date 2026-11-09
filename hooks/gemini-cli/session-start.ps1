. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-start" -Agent "gemini-cli" -FetchHandoff
exit 0
