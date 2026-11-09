# pitstop for Claude Code

Long-term memory across sessions and coding agents, backed by your own
[pitstop](https://github.com/akitaonrails/ai-memory) server. Quit Claude
Code mid-task, open another agent in the same directory, and continue without
re-explaining the context.

This plugin is generated from the pitstop repository
(`pitstop render-plugins`); do not edit it by hand.

## Requirements

The plugin does not contain pitstop. Install the binary once, separately,
and run `pitstop setup` (install script, Homebrew, AUR, RPM, the Docker
wrapper or the macOS app; see the
[install guide](https://github.com/akitaonrails/ai-memory#install)). Without
the binary the plugin captures nothing: it says so once at session start and
never blocks Claude.

The plugin needs pitstop 3.0 or later. With an older binary the hooks
fall back to `http://127.0.0.1:49374` and print an upgrade hint, and the
memory tools do not connect while `server_url` is empty.

## Install

```text
/plugin marketplace add akitaonrails/ai-memory
/plugin install pitstop@pitstop
```

or from a shell:

```sh
claude plugin marketplace add akitaonrails/ai-memory
claude plugin install pitstop@pitstop
```

Claude Code does not auto-update third-party marketplaces unless you turn
that on. `pitstop upgrade` updates the plugin along with a release-tarball
binary; after a Homebrew, AUR or RPM upgrade, run `claude plugin marketplace
update pitstop` and `claude plugin update pitstop@pitstop`.

## What it runs and what it sends

- Hooks: every lifecycle event (session start and end, prompts, tool
  calls, compaction, stop, subagents) runs `scripts/pitstop-hook`, a short
  POSIX shell script you can read in full. It finds the installed `pitstop`
  binary and hands it the event with `pitstop hook`. The binary applies
  your capture exclusions (`ignore_paths`, allowlist mode, server profiles)
  before anything is written or sent, spools the event locally, and delivers
  it only to your pitstop server, which sanitizes it before storage.
- MCP: the pitstop memory tools, through `pitstop mcp-bridge`.
- Skills: the pitstop routing skills, plus `/pitstop:status`, which
  runs `pitstop doctor` and summarizes it.

No telemetry. Nothing goes anywhere except the pitstop server you
configure. Hooks from a plugin run with your user permissions, outside
Claude's sandbox, like any Claude Code hook.

Sessions with no project folder (a desktop scratch workspace) are not
captured through the plugin.

## Options

All optional; the defaults match a local `pitstop setup` install. Set them
with `/plugin configure pitstop@pitstop`.

| Option | Default | Use |
| --- | --- | --- |
| `server_url` | empty | Empty uses the `server_url` from your pitstop config. Set it only to point this plugin elsewhere. |
| `pitstop_bin` | `pitstop` | Absolute path to the binary when it is not on `PATH`. A relative path is ignored: it would resolve inside the checkout. |
| `data_dir` | empty | Only for an install with a non-default data directory. |

There is no token option. Hooks and the MCP bridge use the credentials the
pitstop CLI already stores (`pitstop setup`, `auth login`).

## Already using `pitstop install-hooks`?

If your Claude settings already carry pitstop hooks, those win: the plugin
skips every event they deliver, so nothing is captured twice. `pitstop
doctor` reports the double install and suggests keeping one. `pitstop
setup` leaves Claude's settings alone while the plugin is enabled.

## Platform notes

- On Windows, Claude Code runs plugin hooks through Git Bash, which it
  already requires; the launcher needs nothing else.
- With the Docker wrapper, plugin hooks need a wrapper that routes `pitstop
  hook` to its native client; run `pitstop upgrade` to get it.
- In Cowork, capture runs on your computer and needs pitstop installed
  there; the memory tools still work.

## Uninstall

```sh
claude plugin uninstall pitstop@pitstop
```

`pitstop uninstall` offers the same step.

## License

MIT, see `LICENSE`.
