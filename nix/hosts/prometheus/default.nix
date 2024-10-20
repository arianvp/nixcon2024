{
  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [{
      job_name = "node_exporter";
      ec2_sd_configs = [{
        region = "eu-central-1";
        port = 9100;
      }];
    }];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "24.11";

}
