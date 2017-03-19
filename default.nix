let
  project = "windowTest";
  inherit (import ./refs.nix {})
    sources sourceDrvs c2nResultsWith;
  pkgs = import sources.nixpkgs {};
  inherit (pkgs.haskell.lib) overrideCabal disableHardening addPkgconfigDepend addBuildTool;
  haskellPackages =
    pkgs.haskell.packages.ghc801.override {
      overrides = self: super:
        let
          c2n = c2nResultsWith self.runCabal2Nix;
        in {
          runCabal2Nix = import ./runCabal2Nix.nix { compilerName = self.ghc.name; inherit pkgs; };

          gtk2hs-buildtools-local = self.callPackage (c2n.relSourceDrvs.gtk2hs "gtk2hs-buildtools-local" "tools") {}; 

          glib =
            let pkg = self.callPackage (c2n.relSourceDrvs.gtk2hs "glib" "glib") { inherit (pkgs) glib; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening (addPkgconfigDepend (addBuildTool pkg self.gtk2hs-buildtools-local) pkgs.glib) ["fortify"];

          gio =
            let pkg = self.callPackage (c2n.relSourceDrvs.gtk2hs "gio" "gio") { system-glib = pkgs.glib; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening (addPkgconfigDepend (addBuildTool pkg self.gtk2hs-buildtools-local) pkgs.glib) ["fortify"];

          gtk3 =
            let pkg = self.callPackage (c2n.relSourceDrvs.gtk2hs "gtk3" "gtk") { inherit (pkgs) gtk3; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening pkg ["fortify"];

          cairo =
            let pkg = self.callPackage (c2n.relSourceDrvs.gtk2hs "cairo" "cairo") { inherit (pkgs) cairo; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              addBuildTool pkg self.gtk2hs-buildtools-local;

          pango =
            let pkg = self.callPackage (c2n.relSourceDrvs.gtk2hs "pango" "pango") { inherit (pkgs) pango; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening (addBuildTool pkg self.gtk2hs-buildtools-local) ["fortify"];

          webkitgtk3 = self.callPackage c2n.sourceDrvs.webkitgtk3 { webkit = pkgs.webkitgtk24x; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };

          webkitgtk3-javascriptcore = self.callPackage c2n.sourceDrvs.webkitgtk3-javascriptcore { webkit = pkgs.webkitgtk24x; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };

          ghcjs-dom =
            let pkg = self.callPackage c2n.hackageDrvs.ghcjs-dom {};
            in
              overrideCabal pkg (drv: {
                preConfigure = ''
                  sed -i 's/\(transformers .*\)<0.5/\1<0.6/' *.cabal
                '';
              });

          intero =
            let pkg = self.callPackage c2n.sourceDrvs.intero {};
            in
              overrideCabal pkg (drv: {
                postPatch = (drv.postPatch or "") + ''
                  substituteInPlace src/test/Main.hs --replace "\"intero\"" "\"$PWD/dist/build/intero/intero\""
                '';
              });

          reflex = self.callPackage sourceDrvs.reflex {};

          reflex-dom = self.callPackage sourceDrvs.reflex-dom {};
        };
    };
in
  overrideCabal
    (haskellPackages.callPackage (haskellPackages.runCabal2Nix.forLocalPath "${project}" ./.) {})
    (drv: {
      src = builtins.filterSource (path: type: baseNameOf path != ".git") drv.src;
    })
