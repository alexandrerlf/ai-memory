. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "subagent-start" -Agent "grok"
exit 0
