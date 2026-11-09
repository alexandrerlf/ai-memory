. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "stop" -Agent "copilot-cli"
exit 0
