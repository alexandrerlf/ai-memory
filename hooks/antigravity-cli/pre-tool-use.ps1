. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "pre-tool-use" -Agent "antigravity-cli"
[Console]::Out.WriteLine('{ "decision": "allow" }')
exit 0
