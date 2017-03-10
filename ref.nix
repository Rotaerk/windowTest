{
  pkgs ? import <nixpkgs> {},
  baseDir ? ./.,
  refDir ? baseDir + /ref
}:

let
  inherit (pkgs.lib) filterAttrs mapAttrs mapAttrsToList;
  refs =
    mapAttrs
      (fileName: fileType: import (refDir + "/${fileName}"))
      (
        filterAttrs
          (fileName: fileType: fileType == "regular")
          (builtins.readDir refDir)
      );

in rec {
  sources =
    filterAttrs (refName: source: source != null) (
      mapAttrs
        (refName: ref:
          if ref.scheme == "github" then
            pkgs.fetchFromGitHub { inherit (ref) owner repo rev sha256; }
          else
            null
        )
        refs
    );

  relSourceDrvs =
    mapAttrs
      (refName: srcPath:
        (subDir: import (srcPath + "/${subDir}"))
      )
      sources;

  sourceDrvs = mapAttrs (refName: subdirDrv: subdirDrv "") relSourceDrvs;

  c2nResultsWith = runCabal2Nix: rec {
    relSourceNixs =
      mapAttrs
        (refName: srcPath:
          (resultNamePrefix: subDir:
            import (runCabal2Nix.forLocalPath resultNamePrefix (srcPath + "/" + subDir))
          )
        )
        sources;

    sourceNixs = mapAttrs (refName: subdirDrv: subdirDrv refName "") relSourceNixs;

    hackageNixs =
      let
        hackageRefs = filterAttrs (refName: ref: ref.scheme == "hackage") refs;
        drvsPath =
          runCabal2Nix.forHackagePackages "hackageRefs" (
            mapAttrsToList
              (refName: ref: { inherit (ref) packageId sha256; })
              hackageRefs
          );
      in
        mapAttrs (refName: ref: import "${drvsPath}/${ref.packageId}") hackageRefs;
  };
}
