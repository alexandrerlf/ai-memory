. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "subagent-stop" -Agent "dsh"
exit 0
