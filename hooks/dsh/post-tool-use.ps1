. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "dsh"
exit 0
