{
  description = "NixOS Village AWS cloud";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = inputs@{ self, nixpkgs, ... }: {
    lib.supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    lib.forAllSystems = nixpkgs.lib.genAttrs self.lib.supportedSystems;

    devShells = self.lib.forAllSystems (system: {
      default = with nixpkgs.legacyPackages.${system};
        mkShell {
          packages = [
            opentofu
            awscli2
            (tflint.withPlugins (p: [ p.tflint-ruleset-aws ]))
            actionlint
            shellcheck
            infracost
            gh
          ];
          # shellHook = self.checks.${system}.pre-commit-check.shellHook;
        };
    });

    hydraJobs = {
      toplevels =
        nixpkgs.lib.mapAttrs (name: config: config.config.system.build.toplevel)
        self.nixosConfigurations;
      images = nixpkgs.lib.mapAttrs
        (name: config: config.config.system.build.amazonImage)
        self.nixosConfigurations;
    };

    nixosConfigurations = let
      lib = nixpkgs.lib;
      hosts = builtins.readDir ./nix/hosts;
      nixosSystem = name: _v:
        lib.nixosSystem {
          modules = [
            "${nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
            {
              amazonImage.sizeMB = "auto";
              amazonImage.format = "raw";
            }
            { system.name = name; }
            ./nix/hosts/${name}
          ];
        };
    in lib.mapAttrs nixosSystem hosts;
  };
}
