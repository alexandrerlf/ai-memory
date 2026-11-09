. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "pre-compact" -Agent "gemini-cli"
exit 0
