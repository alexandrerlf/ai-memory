# Kiro CLI v2 post-tool-use hook (postToolUse).
. "$PSScriptRoot\..\lib\pitstop-hook.ps1"
Invoke-PitstopHook -Event "post-tool-use" -Agent "kiro-cli"
exit 0
