{
  mkShell,
  musl,
  graphviz,
  alice,
}:

mkShell {
  inputsFrom = [
    alice.package
  ];
  nativeBuildInputs = [ graphviz ];
  buildInputs = [ musl ];
}
