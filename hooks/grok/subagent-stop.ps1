. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "subagent-stop" -Agent "grok"
exit 0
