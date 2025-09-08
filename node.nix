{
  lib,
  pkgs,
  ...
}:
{
  system.stateVersion = "25.11";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = lib.mkDefault "node1";

  users.users.root.password = "root";

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      curl
      nettools
      ;
  };

  services.getty.autologinUser = "root";

  services.hapsql = {
    enable = true;
    nodeIp = "10.0.2.15";
    partners = [
      "10.0.2.16"
      "10.0.2.17"
    ];
  };
}
