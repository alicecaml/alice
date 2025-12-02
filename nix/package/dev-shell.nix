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
  buildInput = [ musl ];
}
