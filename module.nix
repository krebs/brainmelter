{ self }:

{ config, lib, pkgs, ... }:

with lib;

let
  brainmelterPkgs = self.packages.${pkgs.system};
in {
  options.services.brainmelter = {
    enable = mkEnableOption "Enable BrainMelter services";
    numberOfHarbors = mkOption {
      type = types.int;
      default = 6;
      description = "Number of Liquidsoap harbor inputs to listen on.";
    };
  };

  config = mkIf config.services.brainmelter.enable {
    users.users.brainmelter = {
      isSystemUser = true;
      group = "brainmelter";
    };
    users.groups.brainmelter = {};

    systemd.services.brainmelter-brockman = {
      description = "BrainMelter Shell Script";
      after = [ "brainmelter-mixer.service" ];
      requires = [ "brainmelter-mixer.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        BRAINMELTER_HARBORS = toString config.services.brainmelter.numberOfHarbors;
      };
      serviceConfig = {
        ExecStart = "${brainmelterPkgs.irc-input}/bin/irc-input";
        Restart = "on-failure";
        User = "brainmelter";
        Group = "brainmelter";
      };
    };

    systemd.services.brainmelter-mixer = {
      description = "BrainMelter Liquidsoap Script";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        BRAINMELTER_HARBORS = toString config.services.brainmelter.numberOfHarbors;
      };
      serviceConfig = {
        ExecStart = "${brainmelterPkgs.mixer}/bin/mixer";
        Restart = "on-failure";
        User = "brainmelter";
        Group = "brainmelter";
      };
    };
  };
}
