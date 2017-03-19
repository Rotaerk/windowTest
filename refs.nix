{
  pkgs ? import <nixpkgs> {},
  baseDir ? ./.,
  refDir ? baseDir + /refs
}:

let
  lib = import ./lib.nix { inherit pkgs; };
  inherit (lib) compose composeAll;
  inherit (pkgs.lib) filterAttrs mapAttrs mapAttrsToList;
  refs =
    composeAll [
      (mapAttrs (fileName: fileType: import (refDir + "/${fileName}")))
      (filterAttrs (fileName: fileType: fileType == "regular"))
      builtins.readDir
    ]
      refDir;

in rec {
  sources =
    compose
      (filterAttrs (refName: source: source != null))
      (mapAttrs
        (refName: ref:
          if ref.scheme == "github" then
            pkgs.fetchFromGitHub { inherit (ref) owner repo rev sha256; }
          else
            null
        )
      )
      refs;

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
