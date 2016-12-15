let
  nixpkgs = import <nixpkgs> {};
in
  nixpkgs.lib.mapAttrs
    (depName: manifest:
      nixpkgs.fetchFromGitHub (
        manifest // {
          sha256 = builtins.readFile (./hashes + "/${depName}");
        }
      )
    )
    (import ./manifests.nix)
