---
name: debug
description: Structured debugging workflow. Use when fixing bugs, runtime errors, or unexpected behavior to ensure all code paths are checked.
---

# Debug Workflow

Follow these steps in order:

1. **Reproduce**: Read the error message and identify the failing file/line
2. **Search broadly**: Grep for ALL code paths that could trigger this issue — not just the first match
   - Search for related function calls, event handlers, and bindings
   - List every occurrence with file:line references
3. **Root cause**: Identify the underlying issue, not just the symptom
4. **Fix all paths**: Propose a fix covering EVERY code path found in step 2
5. **Validate**:
   - If QML: check API compatibility with the Qt version in use, avoid Qt5Compat unless confirmed
   - If Nix: run `nix eval` or `nix flake check` to verify no eval errors
   - If Python: check imports and type compatibility
6. **Report**: Summarize what was wrong, what was fixed, and which files were changed
