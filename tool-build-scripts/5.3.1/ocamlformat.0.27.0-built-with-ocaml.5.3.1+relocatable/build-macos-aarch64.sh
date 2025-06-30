#!/bin/sh

# Build ocamlformat with the relocatable compiler. This script is mostly
# hermetic however currently it requires "dune" be in your PATH when the script
# is run.

set -ex

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice)
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"
cd "$TMP"

wget "$COMPILER_URL"
echo 5df182e10051f927a04f186092f34472a5a12d837ddb2531acbc2d4d2544e5d6  ocaml-macos-aarch64.5.3.1+relocatable.tar.gz | sha256sum -c
tar xf ocaml-macos-aarch64.5.3.1+relocatable.tar.gz

which ocamlc
which dune

git clone --depth 1 --single-branch --branch 0.27.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocamlformat
cd ocamlformat
dune build
cd ..
mkdir ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable
for dir in bin man share; do
    cp -rv ocamlformat/_build/install/default/$dir ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable
done
mkdir -p ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable/doc
cp -rv ocamlformat/_build/install/default/doc/ocamlformat ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable/doc

tar czf ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable
cp ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz "$ORIGINAL_DIR/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz"
