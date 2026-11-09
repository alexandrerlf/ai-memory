---
name: status
description: Check whether pitstop is capturing this session and its memory tools can reach the server. Run it when memory looks missing or after installing or upgrading pitstop.
disable-model-invocation: true
---

# pitstop status

Report on the pitstop install this session uses. Only report: do not
change any file, setting or hook, and do not run any command other than the
two below.

1. Run `pitstop --version`. If the command is not found, say that the
   pitstop binary is not installed (or not on `PATH`), that this session is
   therefore not captured while the memory tools may still answer from an
   pitstop server, and point to
   <https://github.com/akitaonrails/ai-memory#install>. Stop there.
2. Run `pitstop doctor` in the current project directory.

Summarize the doctor output in a few short lines:

- whether the server answered, and which server URL it used;
- the workspace and project this directory maps to;
- capture coverage for this agent, and any agent it flags as uncaptured;
- the hook spool backlog, if any events are waiting;
- duplicate wiring: the pitstop plugin and settings-file hooks (or
  installed skills) both active, and which one doctor suggests keeping;
- for Codex, any pitstop hook Codex skips as `untrusted` or `modified`
  (the user trusts them in `/hooks`);
- the pitstop plugin version against the binary version, when they differ.

Quote problems as doctor states them, and leave every fix to the user.
