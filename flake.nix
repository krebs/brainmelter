{
  description = "BrainMelter flake with Liquidsoap and Shell script";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        packages = {
          mixer = pkgs.writeShellScriptBin "mixer" ''
            exec ${pkgs.liquidsoap}/bin/liquidsoap ${./mixer.liq}
          '';

          irc-input = pkgs.writeShellScriptBin "irc-input" ''
            export PATH=${pkgs.lib.makeBinPath [ pkgs.ffmpeg pkgs.flite ]}
            exec ${./irc-input.sh}
          '';
        };

      }
    ) // {
      nixosModules.brainmelter = import ./module.nix { inherit self; };
    };
}
