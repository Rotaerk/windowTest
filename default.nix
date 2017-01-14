let
  project = "windowTest";
  depSpecs = import ./dependencies/specsWithHashes.nix;
  fetchFromGitHubUsing = pkgs: args: pkgs.fetchFromGitHub { inherit (args) owner repo rev sha256; };
  pkgs = import (fetchFromGitHubUsing (import <nixpkgs> {}) depSpecs.nixpkgs) {};
  lib = pkgs.haskell.lib;
  fetchFromGitHub = fetchFromGitHubUsing pkgs;
  runCabal2Nix = import ./runCabal2Nix.nix { inherit pkgs; };
  sources = {
    gtk2hs = fetchFromGitHub depSpecs.gtk2hs;
    webkitgtk3 = fetchFromGitHub depSpecs.webkitgtk3;
    webkitgtk3-javascriptcore = fetchFromGitHub depSpecs.webkitgtk3-javascriptcore;
    intero = fetchFromGitHub depSpecs.intero;
    reflex = fetchFromGitHub depSpecs.reflex;
    reflex-dom = fetchFromGitHub depSpecs.reflex-dom;
  };
  inherit (lib) overrideCabal disableHardening addPkgconfigDepend addBuildTool;
  haskellPackages =
    pkgs.haskell.packages.ghc801.override {
      overrides = self: super:
        {
          gtk2hs-buildtools-local = self.callPackage (import (runCabal2Nix.forLocalPath {} "gtk2hs-buildtools-local" "${sources.gtk2hs}/tools")) {}; 

          glib =
            let pkg = self.callPackage (import (runCabal2Nix.forLocalPath {} "glib" "${sources.gtk2hs}/glib")) { inherit (pkgs) glib; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening (addPkgconfigDepend (addBuildTool pkg self.gtk2hs-buildtools-local) pkgs.glib) ["fortify"];

          gio =
            let pkg = self.callPackage (import (runCabal2Nix.forLocalPath {} "gio" "${sources.gtk2hs}/gio")) { system-glib = pkgs.glib; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening (addPkgconfigDepend (addBuildTool pkg self.gtk2hs-buildtools-local) pkgs.glib) ["fortify"];

          gtk3 =
            let pkg = self.callPackage (import (runCabal2Nix.forLocalPath {} "gtk3" "${sources.gtk2hs}/gtk")) { inherit (pkgs) gtk3; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening pkg ["fortify"];

          cairo =
            let pkg = self.callPackage (import (runCabal2Nix.forLocalPath {} "cairo" "${sources.gtk2hs}/cairo")) { inherit (pkgs) cairo; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              addBuildTool pkg self.gtk2hs-buildtools-local;

          pango =
            let pkg = self.callPackage (import (runCabal2Nix.forLocalPath {} "pango" "${sources.gtk2hs}/pango")) { inherit (pkgs) pango; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };
            in
              disableHardening (addBuildTool pkg self.gtk2hs-buildtools-local) ["fortify"];

          webkitgtk3 = self.callPackage (import (runCabal2Nix.forLocalPath {} "webkitgtk3" "${sources.webkitgtk3}")) { webkit = pkgs.webkitgtk24x; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };

          webkitgtk3-javascriptcore = self.callPackage (import (runCabal2Nix.forLocalPath {} "webkitgtk3-javascriptcore" "${sources.webkitgtk3-javascriptcore}")) { webkit = pkgs.webkitgtk24x; gtk2hs-buildtools = self.gtk2hs-buildtools-local; };

          ghcjs-dom =
            let pkg = self.callPackage (import (runCabal2Nix.forHackagePackage {} "ghcjs-dom" depSpecs.ghcjs-dom)) {};
            in
              overrideCabal pkg (drv: {
                preConfigure = ''
                  sed -i 's/\(transformers .*\)<0.5/\1<0.6/' *.cabal
                '';
              });

          intero =
            let pkg = self.callPackage (import (runCabal2Nix.forLocalPath {} "intero" "${sources.intero}")) {};
            in
              overrideCabal pkg (drv: {
                postPatch = (drv.postPatch or "") + ''
                  substituteInPlace src/test/Main.hs --replace "\"intero\"" "\"$PWD/dist/build/intero/intero\""
                '';
              });

          reflex = self.callPackage (import sources.reflex) {};

          reflex-dom = self.callPackage (import sources.reflex-dom) {};
        };
    };
in
  overrideCabal
    (haskellPackages.callPackage (runCabal2Nix.forLocalPath {} "${project}" ./.) {})
    (drv: {
      src = builtins.filterSource (path: type: baseNameOf path != ".git") drv.src;
    })
