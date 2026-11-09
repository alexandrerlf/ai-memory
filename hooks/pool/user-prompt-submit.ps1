. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "user-prompt" -Agent "pool"
exit 0
