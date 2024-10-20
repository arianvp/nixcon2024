{
  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = { system = "x86_64-linux"; };
  services.nginx.enable = true;
}
