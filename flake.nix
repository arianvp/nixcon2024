{
  description = "NixOS Village AWS cloud";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = inputs@{ self, nixpkgs, pre-commit-hooks, ... }: {
    lib.supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    lib.forAllSystems = nixpkgs.lib.genAttrs self.lib.supportedSystems;

    devShells = self.lib.forAllSystems (system: {
      default = with nixpkgs.legacyPackages.${system};
        mkShell {
          packages =
            [ opentofu awscli2 tflint actionlint shellcheck gh ];
          shellHook = self.checks.${system}.pre-commit-check.shellHook;
        };
    });

    checks = self.lib.forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          actionlint.enable = true;
          tflint.enable = true;
          shellcheck.enable = true;
        };
      };
    });

  };
}
