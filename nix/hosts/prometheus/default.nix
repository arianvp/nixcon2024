{
  servces.prometheus = {
    enable = true;
    globalConfigs.scrape_interval = "15s";
    scrapeConfigs = [{
      job_name = "node_exporter";
      ec2_sd_configs = [{
        region = "eu-central-1";
        port = 9100;
      }];
    }];
  };
}
