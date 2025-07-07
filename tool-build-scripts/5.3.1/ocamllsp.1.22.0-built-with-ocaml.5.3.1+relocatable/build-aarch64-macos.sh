#!/bin/sh

# Build ocamllsp with the relocatable compiler. This script is mostly
# hermetic however currently it requires "dune" be in your PATH when the script
# is run.

set -ex

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-aarch64-macos.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice)
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"
cd "$TMP"

wget "$COMPILER_URL"
echo 5df182e10051f927a04f186092f34472a5a12d837ddb2531acbc2d4d2544e5d6  ocaml-aarch64-macos.5.3.1+relocatable.tar.gz | sha256sum -c
tar xf ocaml-aarch64-macos.5.3.1+relocatable.tar.gz

which ocamlc
which dune

git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocaml-lsp
cd ocaml-lsp
dune build
cd ..
mkdir ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
cp -rv ocaml-lsp/_build/install/default/bin ocaml-lsp/_build/install/default/doc ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
tar czf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
cp ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz "$ORIGINAL_DIR/ocamllsp-aarch64-macos.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz"
