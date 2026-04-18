inputs:
{
  pkgs,
  lib,
  ...
}:

let
  statusLineScript = pkgs.writeShellScript "claude-status-line" ''
    input=$(cat)
    model=$(echo "$input" | jq -r '.model.display_name')
    dir=$(echo "$input" | jq -r '.workspace.current_dir')
    echo "[$model] $(basename "$dir")"
  '';
in
{
  # jq is used by the statusLine script and all hooks
  extraPackages = [ pkgs.jq ];

  settings = {
    permissions.allow = [
      "Bash(nix build:*)"
      "Bash(nix develop:*)"
      "Bash(nix flake check:*)"
      "Bash(nix flake update:*)"
      "Bash(nix fmt:*)"
      "Bash(git diff:*)"
      "Bash(git log:*)"
      "Bash(git status:*)"
      "Bash(git show:*)"
    ];
    theme = "dark";
    attribution = {
      commit = "";
      pr = "";
    };
    statusLine = {
      command = "${statusLineScript}";
      padding = 0;
      type = "command";
    };
    hooks.PreToolUse = [
      {
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = ''
              command=$(jq -r '.tool_input.command // empty' <<< "$CLAUDE_TOOL_INPUT")
              if [[ -n "$command" ]] && echo "$command" | grep -qE '(rm\s+-[rf]{1,2}[rf]?|--force|reset\s+--hard|checkout\s+\.|clean\s+-f|branch\s+-[Dd])'; then
                echo "WARNING: Potentially destructive command detected - confirm this is intentional"
              fi
            '';
          }
        ];
      }
    ];
    hooks.PostToolUse = [
      {
        matcher = "Edit|MultiEdit|Write";
        hooks = [
          {
            type = "command";
            command = ''
              file=$(jq -r '.tool_input.file_path // empty' <<< "$CLAUDE_TOOL_INPUT")
              if [[ -n "$file" && "$file" == *.nix ]]; then
                nix fmt "$file" 2>/dev/null
              fi
            '';
          }
        ];
      }
      # Run cargo check after .rs edits
      {
        matcher = "Edit|MultiEdit|Write";
        hooks = [
          {
            type = "command";
            command = ''
              file=$(jq -r '.tool_input.file_path // empty' <<< "$CLAUDE_TOOL_INPUT")
              if [[ -n "$file" && "$file" == *.rs ]]; then
                cargo check --message-format=short 2>&1 | head -20
              fi
            '';
          }
        ];
      }
    ];
  };

  pluginDirs = [
    (lib.fileset.toSource {
      root = ./.;
      fileset = ./skills;
    })
    "${inputs.claude-code-plugins}/plugins/frontend-design"
  ];
}
