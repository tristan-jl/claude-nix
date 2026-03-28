---
name: add-nvim-plugin
description: Add a Neovim plugin to the nixCats-based config. Use when the user wants to add, install, or configure a new Neovim plugin.
---

# Add Neovim Plugin

Follow this pipeline to add a plugin to the nixCats Neovim config:

1. **Read existing patterns**: Check the nvim-nix repo structure — look at existing plugins in `lua/` and `nix/` directories to understand the conventions
2. **Add nix overlay/input**: Follow the EXACT pattern used by existing plugins — copy, don't guess
3. **Add lze loader config**: Match the lazy-loading conventions already in use
4. **Check health**: Run `nvim --headless -c 'checkhealth <plugin>' -c 'qa' 2>&1` to verify it loads
5. **Verify completion priority**: If the plugin adds completion sources, run:
   ```
   nvim --headless -c 'lua print(vim.inspect(require("cmp").get_config().sources))' -c 'qa'
   ```
   LSP must remain highest priority unless told otherwise.
6. **Check keybinding conflicts**: Grep existing keymaps to ensure no collisions
7. Only present the final working result
