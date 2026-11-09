. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "subagent-start" -Agent "claude-code" -SubagentStartBrief
exit 0
