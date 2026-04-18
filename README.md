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
- **Hooks**:
  - `PostToolUse`: auto-format `.nix` files with `nix fmt` on save; run `cargo check` after `.rs` edits
  - `PreToolUse`: warn on potentially destructive bash commands (`rm -rf`, `--force`, `reset --hard`, etc.)

## Skills

Local skills live in `skills/<name>/SKILL.md` and become slash commands (e.g. `skills/debug/` → `/debug`).

Current local skills: `debug`, `review`, `nixcheck`, `add-nvim-plugin`

External skill sources are declared as `flake = false` inputs and added to `pluginDirs` in `module.nix`:

- `claude-code-plugins` — `frontend-design`

### Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter:
   ```markdown
   ---
   name: command-name
   description: One-line description.
   ---
   ```
2. `nix build && nix run`
