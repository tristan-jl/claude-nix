{
  description = "Claude Code configuration with nix-wrapper-modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-plugins = {
      url = "github:anthropics/claude-code";
      flake = false;
    };
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      wrappers,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      coreModule = lib.modules.importApply ./module.nix inputs;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [ wrappers.flakeModules.wrappers ];

      perSystem =
        { system, self', ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          wrappers.pkgs = pkgs;

          packages.default = self'.packages.claude;

          devShells.default = pkgs.mkShell {
            name = "claude";
            packages = [ self'.packages.claude ];
          };
        };

      flake.wrappers.claude =
        { wlib, ... }:
        {
          imports = [
            wlib.wrapperModules.claude-code
            coreModule
          ];
        };
    };
}
