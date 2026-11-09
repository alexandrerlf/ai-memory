. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "antigravity-cli"
[Console]::Out.WriteLine("{}")
exit 0
