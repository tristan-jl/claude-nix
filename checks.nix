{ pkgs }:
let
  hooks = import ./hooks.nix { inherit pkgs; };

  # Feed a hook a real payload and assert on what it does. This is the test that
  # would have caught hooks reading a nonexistent $CLAUDE_TOOL_INPUT env var.
  hookTest = name: script: pkgs.runCommand "check-hook-${name}" { } script;
in
{
  hook-nixfmt = hookTest "nixfmt" ''
    cd "$(mktemp -d)"
    printf '{ x =   1;  y=2; }\n' > sample.nix
    ${pkgs.jq}/bin/jq -n --arg f "$PWD/sample.nix" '{tool_name:"Edit", tool_input:{file_path:$f}}' \
      | ${hooks.nixfmt}/bin/claude-hook-nixfmt

    grep -q 'x = 1;' sample.nix || { echo "FAIL: file was not formatted"; cat sample.nix; exit 1; }

    # Non-nix files must be left alone.
    printf 'x=1\n' > other.py
    ${pkgs.jq}/bin/jq -n --arg f "$PWD/other.py" '{tool_name:"Edit", tool_input:{file_path:$f}}' \
      | ${hooks.nixfmt}/bin/claude-hook-nixfmt
    grep -q '^x=1$' other.py || { echo "FAIL: touched a non-nix file"; exit 1; }

    # A payload with no file_path must exit cleanly rather than error.
    echo '{"tool_name":"Edit","tool_input":{}}' | ${hooks.nixfmt}/bin/claude-hook-nixfmt

    touch $out
  '';

  hook-guard-bash = hookTest "guard-bash" ''
    guard=${hooks.guard-bash}/bin/claude-hook-guard-bash

    # Destructive commands must exit 2 and explain themselves on stderr.
    if err=$(echo '{"tool_input":{"command":"rm -rf /tmp/x"}}' | $guard 2>&1); then
      echo "FAIL: rm -rf was not blocked"; exit 1
    fi
    grep -q 'Blocked' <<< "$err" || { echo "FAIL: no explanation on stderr"; exit 1; }

    echo '{"tool_input":{"command":"git reset --hard HEAD"}}' | $guard 2>/dev/null \
      && { echo "FAIL: reset --hard was not blocked"; exit 1; } || true

    # Ordinary commands must pass through untouched.
    echo '{"tool_input":{"command":"nix build .#claude"}}' | $guard
    echo '{"tool_input":{"command":"git status"}}' | $guard
    echo '{"tool_name":"Read","tool_input":{}}' | $guard

    touch $out
  '';

  hook-cargo-check = hookTest "cargo-check" ''
    hook=${hooks.cargo-check}/bin/claude-hook-cargo-check

    # No cargo on PATH, and no Cargo.toml: must be a clean no-op, not a crash.
    cd "$(mktemp -d)"
    touch lib.rs
    ${pkgs.jq}/bin/jq -n --arg f "$PWD/lib.rs" '{tool_input:{file_path:$f}}' | $hook
    echo '{"tool_input":{"file_path":"/tmp/x.py"}}' | $hook

    touch $out
  '';

  # A SKILL.md whose frontmatter name disagrees with its directory silently
  # fails to register as a command, so assert they match.
  skills = pkgs.runCommand "check-skills" { } ''
    fail=0
    for dir in ${./skills}/*/; do
      name=$(basename "$dir")
      md="$dir/SKILL.md"

      if [[ ! -f "$md" ]]; then
        echo "FAIL: skills/$name has no SKILL.md"; fail=1; continue
      fi

      declared=$(sed -n 's/^name:[[:space:]]*//p' "$md" | head -1)
      if [[ "$declared" != "$name" ]]; then
        echo "FAIL: skills/$name declares name '$declared'"; fail=1
      fi

      if ! grep -q '^description:' "$md"; then
        echo "FAIL: skills/$name has no description (it will not show in the picker)"; fail=1
      fi
    done
    [[ $fail -eq 0 ]] || exit 1
    touch $out
  '';
}
