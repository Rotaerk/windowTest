let
  nixpkgs = import <nixpkgs> {};
in
  nixpkgs.lib.mapAttrs
    (depName: spec:
      spec // {
        sha256 = builtins.readFile (./hashes + "/${depName}");
      }
    )
    (import ./specs.nix)
