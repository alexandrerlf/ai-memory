. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "pre-compact" -Agent "copilot-cli"
exit 0
