. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-end" -Agent "copilot-cli"
exit 0
