#!/bin/sh

# Build ocamlformat with the relocatable compiler. This script is mostly
# hermetic however currently it requires "dune" be in your PATH, with some
# patches applied (use this branch:
# https://github.com/gridbugs/dune/tree/spice-patches).

set -ex

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/spice/compilers/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t spice)
echo $TMP
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"
cd "$TMP"

#wget "$COMPILER_URL"
cp -v ~/src/spice/build-scripts/compiler/5.3.1+relocatable/ocaml-macos-aarch64.5.3.1+relocatable.tar.gz .
tar xf ocaml-macos-aarch64.5.3.1+relocatable.tar.gz

export PATH=$PWD/ocaml.5.3.1+relocatable/bin:$PATH
which ocamlc
which dune

git clone --depth 1 --single-branch --branch 0.27.0-build-with-ocaml.5.3.1+relocatable https://github.com/spiceml/ocamlformat
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
