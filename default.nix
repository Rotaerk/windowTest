{ refsWithLocalSource ? [] }:

let
  project = "windowTest";
  inherit (import ./refs.nix { inherit refsWithLocalSource; })
    sources sourceImports c2nResultsWith relSourceOverrides sourceOverrides;
  pkgs = import sources.nixpkgs {};
  inherit (pkgs.haskell.lib) overrideCabal;
  haskellPackages =
    pkgs.haskell.packages.ghc801.override {
      overrides = self: super:
        let
          c2n = c2nResultsWith self.runCabal2Nix;
        in {
          runCabal2Nix = import ./runCabal2Nix.nix { compilerName = self.ghc.name; inherit pkgs; };

          gtk2hs-buildtools-local = self.callPackage (c2n.relSourceImports.gtk2hs "gtk2hs-buildtools-local" "tools") {}; 

          glib = relSourceOverrides.gtk2hs "glib" "0.13.2.2" super.glib;
          gio = relSourceOverrides.gtk2hs "gio" "0.13.1.1" super.gio;
          gtk3 = relSourceOverrides.gtk2hs "gtk" "0.14.2" super.gtk3;
          cairo = relSourceOverrides.gtk2hs "cairo" "0.13.1.1" super.cairo;
          pango = relSourceOverrides.gtk2hs "pango" "0.13.1.1" super.pango;

          webkitgtk3 = self.callPackage c2n.sourceImports.webkitgtk3 { webkit = pkgs.webkitgtk24x; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };

          webkitgtk3-javascriptcore = self.callPackage c2n.sourceImports.webkitgtk3-javascriptcore { webkit = pkgs.webkitgtk24x; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };

          ghcjs-dom =
            let pkg = self.callPackage c2n.hackageImports.ghcjs-dom {};
            in
              overrideCabal pkg (drv: {
                preConfigure = ''
                  sed -i 's/\(transformers .*\)<0.5/\1<0.6/' *.cabal
                '';
              });

          intero = sourceOverrides.intero "0.1.18" super.intero;

          reflex = self.callPackage sourceImports.reflex {};

          reflex-dom = self.callPackage sourceImports.reflex-dom {};
        };
    };
in
  overrideCabal
    (haskellPackages.callPackage (haskellPackages.runCabal2Nix.forLocalPath "${project}" ./.) {})
    (drv: {
      src = builtins.filterSource (path: type: baseNameOf path != ".git") drv.src;
    })
