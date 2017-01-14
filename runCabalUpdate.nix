{pkgs ? import <nixpkgs> {}}:

{
  repoName ? "hackage",
  repoUrl ? "http://hackage.haskell.org/"
}:

let cabalConfig =
  builtins.toFile "cabal.config" ''
    repository ${repoName}
      url: ${repoUrl}
    remote-repo-cache: .
  '';
in
  pkgs.runCommand "cabalRepoCache" {
    buildInputs = [ pkgs.cabal-install ];
    passthru = { inherit repoName repoUrl; };
  } ''
    mkdir -p "$out"
    cd "$out"
    cabal --config-file="${cabalConfig}" update
  ''
