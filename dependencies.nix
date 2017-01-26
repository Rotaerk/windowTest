{
  pkgs ? import <nixpkgs> {},
  baseDir ? ./.,
  refsFile ? baseDir + /references.nix,
  hashesFolder ? baseDir + /hashes
}:

let
  refs = import refsFile;
  refHash = refName: builtins.readFile (hashesFolder + "/${refName}");
  runCabal2Nix = import ./runCabal2Nix.nix { inherit pkgs; };
  inherit (pkgs.lib) filterAttrs mapAttrs mapAttrsToList;

in rec {
  sources =
    filterAttrs (refName: source: source != null) (
      mapAttrs
        (refName: ref:
          if ref.scheme == "github" then
            pkgs.fetchFromGitHub {
              inherit (ref) owner repo rev;
              sha256 = refHash refName;
            }
          else
            null
        )
        refs
    );

  relSourceDrvs =
    mapAttrs
      (refName: srcPath:
        (subDir: import (srcPath + "/" + subDir))
      )
      sources;

  sourceDrvs = mapAttrs (refName: subdirDrv: subdirDrv "") relSourceDrvs;

  relSourceC2N =
    mapAttrs
      (refName: srcPath:
        (resultNamePrefix: subDir:
          import (runCabal2Nix.forLocalPath resultNamePrefix (srcPath + "/" + subDir))
        )
      )
      sources;

  sourceC2N = mapAttrs (refName: subdirDrv: subdirDrv refName "") relSourceC2N;

  hackageC2N =
    let
      hackageRefs = filterAttrs (refName: ref: ref.scheme == "hackage") refs;
      drvsPath =
        runCabal2Nix.forHackagePackages "hackageRefs" (
          mapAttrsToList
            (refName: ref: {
              inherit (ref) packageId;
              sha256 = refHash refName;
            })
            hackageRefs
        );
    in
      mapAttrs (refName: ref: import "${drvsPath}/${ref.packageId}") hackageRefs;
}
