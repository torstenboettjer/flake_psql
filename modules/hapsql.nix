{
  config,
  lib,
  ...
}:
let
  cfg = config.services.hapsql;
in
{
  options.services.hapsql = {
    enable = lib.mkEnableOption "HA PostgreSQL";

    postgresqlPackage = lib.mkOption {
      type = lib.types.package;
    };

    nodeIp = lib.mkOption {
      type = lib.types.str;
    };

    partners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    services.patroni = {
      enable = true;
      postgresqlPackage = cfg.postgresqlPackage;
      name = config.networking.hostName;
      scope = "my-ha-postgres";
      nodeIp = cfg.nodeIp;

      settings = {
        raft = {
          data_dir = "/var/lib/patroni/raft-${config.services.patroni.scope}";
          self_addr = "${cfg.nodeIp}:5010";
          partner_addrs = map (ip: "${ip}:5010") cfg.partners;
        };
      };
    };
  };
}
