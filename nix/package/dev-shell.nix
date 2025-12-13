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
  buildInputs = [ musl ];
}
