# Hook scripts, built as real derivations so they get shellcheck'd at build time
# and have their dependencies pinned into the store.
#
# Every hook receives its payload as JSON on stdin (NOT via an env var).
# Exit code contract:
#   0 - success, stdout goes to the transcript only
#   2 - blocking error, stderr is fed back to Claude
{ pkgs }:
let
  mkHook =
    name:
    {
      runtimeInputs ? [ ],
      text,
    }:
    pkgs.writeShellApplication {
      name = "claude-hook-${name}";
      runtimeInputs = [ pkgs.jq ] ++ runtimeInputs;
      inherit text;
    };
in
{
  # PostToolUse: format edited .nix files.
  # Uses nixfmt directly rather than `nix fmt`, which needs a flake with a
  # formatter in the current directory and fails silently when there isn't one.
  nixfmt = mkHook "nixfmt" {
    runtimeInputs = [ pkgs.nixfmt ];
    text = ''
      file=$(jq -r '.tool_input.file_path // empty')
      [[ "$file" == *.nix && -f "$file" ]] || exit 0
      nixfmt "$file"
    '';
  };

  # PostToolUse: type-check the crate that owns the edited .rs file.
  # cargo is deliberately not pinned - the toolchain belongs to the project.
  cargo-check = mkHook "cargo-check" {
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      file=$(jq -r '.tool_input.file_path // empty')
      [[ "$file" == *.rs && -f "$file" ]] || exit 0
      command -v cargo >/dev/null || exit 0

      dir=$(dirname "$(realpath "$file")")
      while [[ "$dir" != "/" && ! -f "$dir/Cargo.toml" ]]; do
        dir=$(dirname "$dir")
      done
      [[ -f "$dir/Cargo.toml" ]] || exit 0

      if ! out=$(cargo check --manifest-path "$dir/Cargo.toml" --message-format=short 2>&1); then
        head -20 <<< "$out" >&2
        exit 2
      fi
    '';
  };

  # PreToolUse: block destructive bash commands so they have to be justified.
  # Exit 2 is the only code Claude actually sees - a plain echo is ignorable.
  guard-bash = mkHook "guard-bash" {
    runtimeInputs = [ pkgs.gnugrep ];
    text = ''
      command=$(jq -r '.tool_input.command // empty')
      [[ -n "$command" ]] || exit 0

      pattern='rm[[:space:]]+-[rf]{1,2}|--force|reset[[:space:]]+--hard|checkout[[:space:]]+\.|clean[[:space:]]+-f|branch[[:space:]]+-[Dd]'
      if grep -qE "$pattern" <<< "$command"; then
        echo "Blocked: '$command' looks destructive. Explain why it is needed and ask the user to confirm before retrying." >&2
        exit 2
      fi
    '';
  };
}
