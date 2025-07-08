#!/bin/sh

# Build ocamllsp with the relocatable compiler. This script is mostly
# hermetic however currently it requires "dune" be in your PATH when the script
# is run.

set -ex

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-x86_64-macos.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"
cd "$TMP"

wget "$COMPILER_URL"
echo 993bd258d2b26979888d8c52960115b64b060056b6d17cdf442e8f7d0ff47fbf  ocaml-x86_64-macos.5.3.1+relocatable.tar.gz | sha256sum -c
tar xf ocaml-x86_64-macos.5.3.1+relocatable.tar.gz
export PATH=$PWD/ocaml.5.3.1+relocatable/bin:$PATH

which ocamlc
which dune

git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocaml-lsp
cd ocaml-lsp
dune build
cd ..
mkdir ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
cp -rvL ocaml-lsp/_build/install/default/bin ocaml-lsp/_build/install/default/doc ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
tar czf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
cp ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz "$ORIGINAL_DIR/ocamllsp-x86_64-macos.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz"
