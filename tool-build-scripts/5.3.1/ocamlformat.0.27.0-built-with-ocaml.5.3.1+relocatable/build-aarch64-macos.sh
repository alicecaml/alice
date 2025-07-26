#!/bin/sh

# Build ocamlformat with the relocatable compiler. This script is mostly
# hermetic however currently it requires "dune" be in your PATH when the script
# is run.

set -ex

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-5.3.1+relocatable-aarch64-macos.tar.gz"

TMP=$(mktemp -d -t alice)
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"
cd "$TMP"

wget "$COMPILER_URL"
echo 4e9b683dc39867dcd5452e25a154c2964cd02a992ca4d3da33a46a24b6cb2187  ocaml-5.3.1+relocatable-aarch64-macos.tar.gz | sha256sum -c
tar xf ocaml-5.3.1+relocatable-aarch64-macos.tar.gz
export PATH=$PWD/ocaml-5.3.1+relocatable-aarch64-macos/bin:$PATH

which ocamlc
which dune

git clone --depth 1 --single-branch --branch 0.27.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocamlformat
cd ocamlformat
export DUNE_CONFIG__PORTABLE_LOCK_DIR=enabled
dune build
cd ..
mkdir ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos
for dir in bin man share; do
    cp -rvL ocamlformat/_build/install/default/$dir ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos
done
mkdir -p ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos/doc
cp -rv ocamlformat/_build/install/default/doc/ocamlformat ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos/doc

tar czf ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos
cp ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz "$ORIGINAL_DIR/"
