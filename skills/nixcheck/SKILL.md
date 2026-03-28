---
name: nixcheck
description: NixOS change checklist. Use before making NixOS/flake changes to confirm context and validate after.
---

# NixOS Change Checklist

Before making any NixOS/flake changes:

1. **Read structure**: Read `flake.nix` and the relevant module files to understand the current layout
2. **Confirm host**: Ask the user which host this change targets before generating any deployment commands
3. **Verify paths**: Confirm all referenced file paths and secrets exist before writing config
4. **Make changes**: Apply the minimal necessary edits
5. **Validate**: Run `nix flake check` or `nix build .#<host>` and fix any errors
6. **Syntax check**: Verify `mkIf`/`mkMerge` usage matches nixpkgs conventions
