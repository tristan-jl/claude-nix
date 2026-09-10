inputs:
{
  pkgs,
  lib,
  ...
}:

let
  hooks = import ./hooks.nix { inherit pkgs; };
  mcp = import ./mcp.nix { inherit pkgs; };

  statusLineScript = pkgs.writeShellScript "claude-status-line" ''
    input=$(cat)
    model=$(echo "$input" | jq -r '.model.display_name')
    dir=$(echo "$input" | jq -r '.workspace.current_dir')
    echo "[$model] $(basename "$dir")"
  '';
in
{
  # jq is used by the statusLine script; hooks and MCP servers pin their own
  # dependencies rather than relying on this.
  # nodejs is required by the ponytail plugin, whose hooks shell out to `node`.
  runtimePkgs = [
    pkgs.jq
    pkgs.nodejs
  ];

  mcpConfig = mcp.config;

  strictMcpConfig = true; # only declared servers load

  agents = {
    nix-fixer = {
      description = ''
        Iteratively fix Nix build and evaluation errors. Use when `nix build`,
        `nix flake check`, or `nix eval` fails and the fix is not immediately
        obvious. Runs the build loop itself and reports only the outcome.
      '';
      prompt = ''
        Iterate until the build passes: run the failing command, fix the first
        error (Nix errors cascade), re-run. Use `--show-trace` when the error
        has no location. Look up option/package names via the `nixos` MCP
        server rather than guessing. Stop after three loops with the same error,
        or if the fix needs a caller decision (input change, removed feature).
        Report: what broke, what you changed, pass/fail.
      '';
      tools = [
        "Read"
        "Edit"
        "Write"
        "Bash"
        "Grep"
        "Glob"
      ];
      model = "sonnet";
    };
  };

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
            command = "${hooks.guard-bash}/bin/claude-hook-guard-bash";
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
            command = "${hooks.nixfmt}/bin/claude-hook-nixfmt";
          }
          {
            type = "command";
            command = "${hooks.cargo-check}/bin/claude-hook-cargo-check";
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

    # The Nix equivalent of `/plugin marketplace add DietrichGebert/ponytail`.
    # Its marketplace.json lists a single plugin whose source is "./", so
    # loading the repo root as a plugin dir is the same end state, with the
    # commit pinned in flake.lock instead of installed into ~/.claude.
    inputs.ponytail
  ];
}
