#!/bin/sh

# Build ocamllsp with the relocatable compiler. This script is mostly
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

git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocaml-lsp
cd ocaml-lsp
export DUNE_CONFIG__PORTABLE_LOCK_DIR=enabled
dune build
cd ..
mkdir ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos
cp -rvL ocaml-lsp/_build/install/default/bin ocaml-lsp/_build/install/default/doc ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos
tar czf ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos
cp ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos.tar.gz "$ORIGINAL_DIR/"
