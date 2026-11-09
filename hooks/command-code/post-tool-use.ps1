. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "command-code"
exit 0
