# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Overview

A standalone Nix flake that wraps Claude Code using [nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules). Declaratively configures settings, hooks, and skills. No home-manager dependency.

## Build Commands

```bash
# Build the wrapped claude binary
nix build

# Run Claude Code directly
nix run

# Enter dev shell with claude available
nix develop

# Format Nix files
nixfmt flake.nix module.nix

# Check the flake
nix flake check
```

## Architecture

### Files

- `flake.nix` — inputs, outputs, single `claude` package, checks, formatter
- `module.nix` — settings, skill pluginDirs, jq dependency
- `hooks.nix` — hook scripts as `writeShellApplication` derivations
- `mcp.nix` — MCP server configuration
- `checks.nix` — `nix flake check` suite (hook behaviour tests, skill frontmatter validation)
- `skills/<name>/SKILL.md` — slash command definitions (one directory per command)

### How Skills Work

Each subdirectory of `skills/` is a slash command. The directory name becomes the command name (e.g. `skills/debug/` → `/debug`).

`module.nix` registers `./skills` as a plugin dir via `lib.fileset.toSource`, so only the skills content (not the whole repo) is copied into the Nix store.

### How to Add a Skill

1. Create `skills/<command-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: command-name
   description: One-line description shown in the command picker.
   ---

   # Skill Title

   ...instructions...
   ```

2. Rebuild: `nix build`

### How to Remove a Skill

Delete the `skills/<command-name>/` directory and rebuild.

### How to Add/Remove External Skill Sources

External skill collections are declared as `flake = false` inputs in `flake.nix` and added to `pluginDirs` in `module.nix`. To enable a new source:

```nix
# flake.nix
my-skills = {
  url = "github:owner/my-skills";
  flake = false;
};
```

```nix
# module.nix
pluginDirs = [ ... inputs.my-skills ];
```

To use only specific skills from a source rather than all of them:

```nix
pluginDirs = [ ... "${inputs.my-skills}/skills/debugging" ];
```

To remove a source, delete it from both `pluginDirs` and `flake.nix` inputs, then rebuild.

### Marketplaces vs pluginDirs

The wrapper exposes only `--plugin-dir`; there is no marketplace option, and there does not
need to be. A marketplace is a manifest listing plugins and where to fetch them, and
`/plugin marketplace add` resolves that to "clone this into `~/.claude/plugins` and enable
it" — mutable state outside Nix, with its own update cycle.

Adding the plugin's source directly to `pluginDirs` reaches the same end state with the
commit pinned in `flake.lock`. Check the marketplace's `.claude-plugin/marketplace.json`
first: if a plugin entry's `source` is `"./"`, point `pluginDirs` at the repo root. If it
names a subdirectory, point at that subdirectory instead (as `frontend-design` does).

`ponytail` is wired this way. Its hooks shell out to `node`, which is why `pkgs.nodejs` is
in `runtimePkgs` — without it, its `SessionStart`, `SubagentStart` and `UserPromptSubmit`
hooks fail silently on a system with no ambient node. Its state is written to `~/.claude`,
not the plugin root, so a read-only store path is fine.

### Hooks

Hook scripts live in `hooks.nix` as `pkgs.writeShellApplication` derivations and are
referenced by store path from `module.nix`. Building them as derivations means they are
shellcheck'd at build time and their dependencies are pinned, rather than resolved from
whatever is on PATH.

- `nixfmt` (PostToolUse, `Edit|MultiEdit|Write`) — formats edited `.nix` files with a
  pinned `nixfmt`. Deliberately not `nix fmt`, which requires a flake with a `formatter`
  in the current directory and fails silently otherwise.
- `cargo-check` (PostToolUse, `Edit|MultiEdit|Write`) — walks up from the edited `.rs`
  file to its owning `Cargo.toml` and checks that crate. No-ops if `cargo` is not on PATH.
- `guard-bash` (PreToolUse, `Bash`) — blocks destructive commands.

**Hooks receive their payload as JSON on stdin, not via an environment variable.** There
is no `CLAUDE_TOOL_INPUT`. Read it with `jq -r '.tool_input.file_path // empty'`.

Exit codes: `0` succeeds and stdout is transcript-only; `2` blocks the tool call and feeds
stderr back to Claude. Any other non-zero shows an error to the user but Claude never
sees it — so a hook whose output is meant for Claude must exit `2`.

### Checks

`nix flake check` runs `checks.nix`:

- Each hook is fed a realistic JSON payload and asserted on, including the no-op paths.
- Each `skills/<name>/SKILL.md` must declare `name:` matching its directory and have a
  `description:` — a mismatch means the command silently fails to register.

Add a test alongside any new hook; hooks are otherwise unobservable until they misfire.

### MCP Servers

Configured in `mcp.nix`, wired up via `mcpConfig` in `module.nix`. `strictMcpConfig` is
`true`, so *only* these servers load — nothing from user or project scope.
The one exception: the wrapper passes `<git root>/.mcp.json` via `--mcp-config` when it
exists, so a repo can declare its own servers (`${VAR}` in it expands from the environment).

- `nixos` — `mcp-nixos`. Grounded nixpkgs package and NixOS/home-manager option lookup.
  Prefer it over guessing option names.

**Adding a server:** for anything in nixpkgs, add an entry to `config` in `mcp.nix` using
`pkgs.<server>` directly. Otherwise add a `flake.nix` input first.

Weigh it before adding. Tool schemas load into context at session start and stay there,
stdio servers run for the whole session, and a server that duplicates Read/Grep/Edit adds
tool-choice ambiguity for no gain.

No `mcp-language-server` — these repos are too small for LSP to beat grep. See commit
`e889643` for the full rationale.

### Agents

Declared under `agents` in `module.nix` and passed via `--agents`.

- `nix-fixer` (sonnet) — runs the `nix build`/`nix flake check` loop itself and reports
  only the outcome, keeping verbose Nix traces out of the main context.
