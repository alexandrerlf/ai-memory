. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "session-start" -Agent "copilot-cli" -FetchHandoff -CopilotCliSessionStartOutput
exit 0
