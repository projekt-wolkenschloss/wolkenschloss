{
  config,
  lib,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.grafanaAlloyAgent;
  alloyPort = 12345;
in
{
  options.wolkenschloss.modules.mixins.grafanaAlloyAgent = {
    enable = lib.mkEnableOption "Enables the collection of logs and metrics using Grafana Alloy Agent.";

    serviceAlloyConfigs = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      description = ''
        Additional Alloy configuration files to import. The name of the attribute key will be the name of the alloy variables.
        Must begin with:

        declare "<attribute-key>" {
        	argument "metrics_receiver" {
        		optional = false
        		comment  = "Where to send metrics to"
          }
        	argument "logs_receiver" {
        		optional = false
        		comment  = "Where to send logs to"
          }
        ... 
        }
      '';
      default = { };
      example = {
        myService = ./my-service.alloy;
      };
    };
  };

  config = lib.mkIf moduleConfig.enable {
    services.alloy = {
      enable = true;
      configPath = "/etc/alloy";
      extraFlags = [
        "--server.http.listen-addr=0.0.0.0:${toString alloyPort}"
        "--disable-reporting"
      ];
      environmentFile = config.sops.secrets."grafana/alloy-env".path;
    };

    sops.secrets."grafana/alloy-env" = {
      restartUnits = [ "alloy.service" ];
    };

    # TODO remove once caddy is migrated or external debug access is not required anymore
    networking.firewall.allowedTCPPorts = [ alloyPort ];

    environment.etc =
      let
        baseAlloyConfig = builtins.readFile ./config.alloy;

        mkImportSnippet = serviceName: alloyConfigPath: ''
          import.file "${serviceName}_config" {
            filename = "${alloyConfigPath}"
          }

          ${serviceName}_config.${serviceName} "${serviceName}_config" {
            metrics_receiver = prometheus.remote_write.metrics.receiver
            logs_receiver = loki.write.grafana_loki.receiver
          }
        '';

        servicesAlloyConfig =
          lib.concatMapAttrsStringSep "\n" mkImportSnippet
            moduleConfig.serviceAlloyConfigs;
        extendedAlloyConfig = baseAlloyConfig + servicesAlloyConfig;
      in
      {
        "alloy/config.alloy".text = extendedAlloyConfig;
        "alloy/node-metrics.alloy".source = ./node-metrics.alloy;
        "alloy/node-logs.alloy".source = ./node-logs.alloy;
      };
  };
}
