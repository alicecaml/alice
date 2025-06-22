#!/bin/sh

# Build ocamllsp with the relocatable compiler. This script is mostly hermetic
# however currently it requires "dune" be in your PATH, with some patches
# applied (use this branch:
# https://github.com/gridbugs/dune/tree/spice-patches).

set -ex

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/spice/compilers/ocaml-macos-aarch64.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t spice)
echo $TMP
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"
cd "$TMP"

wget "$COMPILER_URL"
tar xf ocaml-macos-aarch64.5.3.1+relocatable.tar.gz

export PATH=$PWD/ocaml.5.3.1+relocatable/bin:$PATH
which ocamlc
which dune

git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/spiceml/ocaml-lsp
cd ocaml-lsp
dune build
cd ..
mkdir ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
cp -rv ocaml-lsp/_build/install/default/bin ocaml-lsp/_build/install/default/doc ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
tar czf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
cp ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz "$ORIGINAL_DIR/ocamllsp-macos-aarch64.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz"
