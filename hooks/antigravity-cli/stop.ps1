. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "stop" -Agent "antigravity-cli"
[Console]::Out.WriteLine('{"decision":""}')
exit 0
