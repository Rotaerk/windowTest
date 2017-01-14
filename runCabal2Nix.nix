{pkgs ? import <nixpkgs> {}}:

let
  haskellPackages =
    pkgs.haskell.packages.ghc801.override {
      overrides = self: super: {
        cabal2nix =
          pkgs.haskell.lib.overrideCabal
            (self.callPackage (import ./cabal2nix.cabal.nix) {})
            (drv: {
              isLibrary = false;
              enableSharedExecutables = false;
              executableToolDepends = [ pkgs.makeWrapper ];
              postInstall = ''
                exe=$out/libexec/${drv.pname}-${drv.version}/${drv.pname}
                install -D $out/bin/${drv.pname} $exe
                rm -rf $out/{bin,lib,share}
                makeWrapper $exe $out/bin/${drv.pname} --prefix PATH ":" "${pkgs.nix-prefetch-scripts}/bin"
                mkdir -p $out/share/bash-completion/completions
                $exe --bash-completion-script $exe >$out/share/bash-completion/completions/${drv.pname}
              '';
            });
      };
    };
  cabal2nix = haskellPackages.cabal2nix;
in {

  forLocalPath =
    {
      resultFileName ? "default.nix"
    }:
    resultNamePrefix:
    localPath:

      pkgs.runCommand "${resultNamePrefix}.c2n" {
        buildInputs = [ cabal2nix ];
        passthru = { inherit localPath resultFileName; };
      } ''
        mkdir -p "$out"
        cabal2nix file://"${localPath}" >"$out/${resultFileName}"
      '';

  forHackagePackage =
    {
      hackageCachePath ?
        let hackageCache = import ./runCabalUpdate.nix { inherit pkgs; } {};
        in "${hackageCache}/${hackageCache.repoName}/00-index.tar",
      resultFileName ? "default.nix"
    }:
    resultNamePrefix:
    { packageId, sha256, ... }:
    
      pkgs.runCommand "${resultNamePrefix}.c2n" {
        buildInputs = [ cabal2nix ];
        passthru = { inherit packageId sha256 hackageCachePath resultFileName; };
      } ''
        mkdir -p "$out" "$out/home"
        HOME="$out/home" cabal2nix --hackage-db="${hackageCachePath}" --sha256="${sha256}" "cabal://${packageId}" >"$out/${resultFileName}"
        rm -rf "$out/home"
      '';
}
