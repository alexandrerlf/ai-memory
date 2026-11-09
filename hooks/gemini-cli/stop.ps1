. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "stop" -Agent "gemini-cli"
exit 0
