{
  pkgs ? import <nixpkgs> {},
  baseDir ? ./.,
  refsDir ? baseDir + /refs,
  refsWithLocalSource ? []
}:

let
  inherit (import ./lib.nix { inherit pkgs; }) compose composeAll;
  inherit (pkgs.lib) filterAttrs mapAttrs mapAttrsToList;
  inherit (pkgs.haskell.lib) overrideCabal;
  refs =
    composeAll [
      (mapAttrs (fileName: fileType: import (refsDir + "/${fileName}")))
      (filterAttrs (fileName: fileType: fileType == "regular"))
      builtins.readDir
    ]
      refsDir;

in rec {
  sources =
    compose
      (filterAttrs (refName: source: source != null))
      (mapAttrs
        (refName: ref:
          if builtins.elem refName refsWithLocalSource then (
            if ref.scheme == "github" then
              refsDir + "/${refName}.git"
            else
              null
          )
          else (
            if ref.scheme == "github" then
              pkgs.fetchFromGitHub { inherit (ref) owner repo rev sha256; }
            else
              null
          )
        )
      )
      refs;

  relSourceOverrides =
    mapAttrs
      (refName: srcPath:
        (subDir: version: pkg:
          overrideCabal pkg
            (drv:
            {
              src = srcPath + "/${subDir}";
              inherit version;
              sha256 = null;
              revision = null;
              editedCabalFile = null;
            }
            )
        )
      )
      sources;

  sourceOverrides = mapAttrs (refName: subdirOverride: subdirOverride "") relSourceOverrides;

  relSourceDrvs =
    mapAttrs
      (refName: srcPath:
        subDir: import (srcPath + "/${subDir}")
      )
      sources;

  sourceDrvs = mapAttrs (refName: subdirDrv: subdirDrv "") relSourceDrvs;

  c2nResultsWith = runCabal2Nix: rec {
    relSourceDrvs =
      mapAttrs
        (refName: srcPath:
          (resultNamePrefix: subDir:
            import (runCabal2Nix.forLocalPath resultNamePrefix (srcPath + "/" + subDir))
          )
        )
        sources;

    sourceDrvs = mapAttrs (refName: subdirDrv: subdirDrv refName "") relSourceDrvs;

    hackageDrvs =
      let
        hackageRefs =
          compose
            (mapAttrs
              (refName: ref:
                {
                  packageId = "${ref.name}-${ref.version}";
                  inherit (ref) sha256;
                }
              )
            )
            (filterAttrs (refName: ref: ref.scheme == "hackage"))
            refs;
        drvsPath =
          runCabal2Nix.forHackagePackages "hackageRefs" (builtins.attrValues hackageRefs);
      in
        mapAttrs (refName: ref: import "${drvsPath}/${ref.packageId}") hackageRefs;
  };
}
