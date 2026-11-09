. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "pool"
exit 0
