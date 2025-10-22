{
  description = "Confidential Cards processor";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.nitro-tee.url = "github:aws/nitrotpm-attestation-samples/nix";
  outputs =
    { nixpkgs, nitro-tee, ... }:
    {
      packages.aarch64-linux.cards-processor = nitro-tee.lib.aarch64-linux.tee-image {
        userConfig =
          { pkgs, ... }:
          {
            systemd.services.cards-processor = {
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.mwb}/bin/cards-processor --kms-key-id arn:aws:us-east-1:283823:kms:key/283238171";
              };
            };
          };
      };
    };
}
