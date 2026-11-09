. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "claude-code"
exit 0
