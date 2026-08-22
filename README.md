# claude-nix

A Nix flake that wraps [Claude Code](https://github.com/anthropics/claude-code) with declarative configuration: settings, hooks, permissions, and skills — no home-manager required.

## Usage

```bash
# Run Claude Code
nix run

# Enter a dev shell with claude on PATH
nix develop

# Build the wrapped binary
nix build
```

## What's configured

- **Theme**: dark
- **Status line**: shows current model and working directory
- **Permissions**: common nix/git read-only operations pre-approved globally
- **Hooks** (defined in `hooks.nix`, shellcheck'd and dependency-pinned at build time):
  - `PostToolUse`: format edited `.nix` files with `nixfmt`; `cargo check` the crate owning an edited `.rs` file
  - `PreToolUse`: block destructive bash commands (`rm -rf`, `--force`, `reset --hard`, etc.)
- **MCP servers** (`mcp.nix`, `strictMcpConfig = true`):
  - `nixos` — grounded nixpkgs package/option lookup via `mcp-nixos`
- **Agents**: `nix-fixer` — runs the Nix build/fix loop and reports only the outcome
- **Checks**: `nix flake check` exercises each hook against a real payload and validates skill frontmatter

## Skills

Local skills live in `skills/<name>/SKILL.md` and become slash commands (e.g. `skills/debug/` → `/debug`).

Current local skills: `debug`, `review`, `nixcheck`

External skill sources are declared as `flake = false` inputs and added to `pluginDirs` in `module.nix`:

- `claude-code-plugins` — `frontend-design`
- `ponytail` — minimal-code ruleset; adds `/ponytail`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`

### Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter:
   ```markdown
   ---
   name: command-name
   description: One-line description.
   ---
   ```
2. `nix build && nix run`
