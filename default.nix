let
  project = "windowTest";
  depSources = import ./dependencies/sources.nix;
  nixpkgs = import depSources."nixpkgs-17.03" {};
  lib = nixpkgs.haskell.lib;
  haskellPackages =
    nixpkgs.haskell.packages.ghc801.override {
      overrides = self: super: {
        reflex = self.callPackage (import depSources."reflex-0.5.0") {};
        reflex-dom = self.callPackage (import depSources."reflex-dom-0.4") {};
      };
    };
in
  lib.overrideCabal
    (haskellPackages.callPackage (./. + "/${project}.cabal.nix") {})
    (drv: {
      src = builtins.filterSource (path: type: baseNameOf path != ".git") drv.src;
    })
