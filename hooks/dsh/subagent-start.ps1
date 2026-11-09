. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "subagent-start" -Agent "dsh"
exit 0
