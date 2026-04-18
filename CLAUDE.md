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

- `flake.nix` — inputs, outputs, single `claude` package
- `module.nix` — settings, hooks, skill pluginDirs, jq dependency
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

### Hooks

Configured in `module.nix` under `settings.hooks.PostToolUse`, triggered on `Edit`/`MultiEdit`/`Write`:

- **`.nix` files** — runs `nix fmt` on the edited file, then checks `nix eval --raw .#nixosConfigurations` (first 5 lines)
- **`.rs` files** — runs `cargo check --message-format=short` (first 20 lines)

`jq` is declared in `extraPackages` so hooks can use it from PATH without a hardcoded store path.

### How to Add an MCP Server

1. Add a flake input in `flake.nix` (if the server isn't already in nixpkgs):
   ```nix
   my-mcp-server = {
     url = "github:owner/my-mcp-server";
   };
   ```
2. In `module.nix`, add the server binary to `extraPackages` and configure it:

   ```nix
   extraPackages = [ pkgs.jq inputs.my-mcp-server.packages.${pkgs.stdenv.hostPlatform.system}.default ];

   mcpConfig = {
     my-server = {
       command = "my-mcp-server";
       type = "stdio";
     };
   };
   ```

   For servers available in nixpkgs, skip the flake input and use `pkgs.my-mcp-server` directly.
