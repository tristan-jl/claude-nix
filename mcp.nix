# MCP server configuration.
#
# Every enabled server's tool schemas are loaded into context at session start
# and stay there, and stdio servers run as child processes for the whole
# session. Prefer servers that solve a problem Claude actually gets wrong, over
# ones that duplicate what Read/Grep/Edit already do well.
{ pkgs }:
{
  config = {
    # Grounded nixpkgs package and NixOS/home-manager option lookup, so option
    # names come from the real option set rather than being guessed.
    nixos = {
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      type = "stdio";
    };
  };
}
