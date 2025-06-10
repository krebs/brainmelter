{ self }:

{ config, lib, pkgs, ... }:

with lib;

let
  brainmelterPkgs = self.packages.${pkgs.system};
in {
  options.services.brainmelter = {
    enable = mkEnableOption "Enable BrainMelter services";
    hostname = mkOption {
      type = types.str;
      description = "Where to host the icecast server";
    };
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

    services.icecast = {
      enable = true;
      hostname = config.services.brainmelter.hostname;
      admin.password = "hackme";
      listen.port = 6457;
      extraConf = ''
        <authentication>
          <source-password>${icecastPassword}</source-password>
        </authentication>
      '';
    };

    services.liquidsoap.streams.brainmelter-mixer = pkgs.writeText "mixer.liq" ''
      ${builtins.readText ./mixer.liq}

      name = "brainmelter"
      genre = "news"
      description = "melts your brain"
      audio = mixed

      output.icecast(%vorbis, audio, mount = name ^ ".ogg", genre = genre, description = description,
        port = ${toString config.services.icecast.listen.port},
        password = "${icecastPassword}",
      )
      output.icecast(%opus, audio, mount = name ^ ".opus", genre = genre, description = description,
        port = ${toString config.services.icecast.listen.port},
        password = "${icecastPassword}",
      )
    '';
  };
}
