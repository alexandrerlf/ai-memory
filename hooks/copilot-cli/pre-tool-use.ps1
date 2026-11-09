. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "pre-tool-use" -Agent "copilot-cli"
exit 0
