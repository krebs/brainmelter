{ self }:

{ config, lib, pkgs, ... }:

with lib;

let
  brainmelterPkgs = self.packages.${pkgs.system};
  icecastPassword = "hackme";
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

    services.nginx.virtualHosts.${config.services.brainmelter.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.icecast.listen.port}";
    };

    services.liquidsoap.streams.brainmelter-mixer = pkgs.writeText "mixer.liq" ''
      set("log.level", 3)

      set("harbor.bind_addr", "0.0.0.0")
      set("harbor.port", 8005)

      number_of_harbors = int_of_string(environment.get("BRAINMELTER_HARBORS", default="6"))

      input_ids = list.init(number_of_harbors, fun(x) -> x + 1)

      inputs = list.map(
        fun(index) -> input.harbor("#{index}", id="#{index}_input", buffer=0.5),
        input_ids
      )

      fallbacks = list.map(
        fun(index_input) -> fallback(
          track_sensitive=false,
          [snd(index_input), blank(duration=1.0)],
          id="fallback_#{fst(index_input)}"
        ),
        list.indexed(inputs)
      )

      mixed = add(fallbacks)

      print("BrainMelter is running!")
      print("Available inputs: #{input_ids}")
      print("HTTP stream available at: http://localhost:8001/brainmelter.mp3")
      print("System ready!")

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
