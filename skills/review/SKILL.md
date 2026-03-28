---
name: review
description: Codebase review for quality, dead code, duplication, and anti-patterns. Adapts to the language/stack in use.
---

# Codebase Review

1. **Dead code**: Find unused functions, variables, imports, and exports
2. **Duplication**: Identify repeated logic across files that could be consolidated
3. **Anti-patterns**: Flag patterns that are idiomatic red flags for this language/stack
4. **Lint**: Run the appropriate linter for the stack (e.g. `cargo clippy`, `eslint`, `ruff`, `nix flake check`) and report all warnings
5. **Build check**: Verify the project compiles/builds cleanly with the relevant build command (e.g. `cargo build`, `npm run build`, `nix build`)
6. **Summary**: Report findings as a structured list grouped by severity — fix immediately / worth addressing / minor
