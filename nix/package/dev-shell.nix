{
  mkShell,
  musl,
  graphviz,
  alice,
}:

mkShell {
  inputsFrom = [
    alice
  ];
  nativeBuildInputs = [ graphviz ];
  buildInput = [ musl ];
}
