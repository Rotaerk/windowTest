{ mkDerivation, base, containers, dependent-sum, directory
, ghcjs-dom, gtk3, mtl, ref-tf, reflex, reflex-dom, stdenv, text
, transformers, webkitgtk3
}:
mkDerivation {
  pname = "windowTest";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base containers dependent-sum directory ghcjs-dom gtk3 mtl ref-tf
    reflex reflex-dom text transformers webkitgtk3
  ];
  description = "A spike solution testing the spawning of multiple windows from the same process using reflex-dom";
  license = stdenv.lib.licenses.bsd3;
}
