. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "pre-tool-use" -Agent "gemini-cli"
exit 0
