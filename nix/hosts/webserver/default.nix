{
  imports = [
    ../../mixins/observability.nix
  ];
  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = { system = "x86_64-linux"; };
  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 ];
}
