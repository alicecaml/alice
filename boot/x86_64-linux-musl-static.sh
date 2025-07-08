#!/bin/sh

# Bootsrapping script for x86_64-linux-musl-static. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-x86_64-linux-musl-static.5.3.1%2Brelocatable.tar.gz"
OCAMLLSP_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
OCAMLFORMAT_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamlformat-x86_64-linux-musl-static.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$COMPILER_URL"
wget "$OCAMLLSP_URL"
wget "$OCAMLFORMAT_URL"

echo 0f052512674e626eb66d90c59e6c076361058ecb7c84098ee882b689de9dbdc1  ocaml-x86_64-linux-musl-static.5.3.1+relocatable.tar.gz | sha256sum -c
echo b57771fab764dbf2fc1703809f8238bafc35a811c150471e14498ee26fe50a00  ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c
echo 7e8393a1b0501693c505c2bebacfe5357d8a466c0158739a05283670579eb4da  ocamlformat-x86_64-linux-musl-static.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c

tar xf ocaml-x86_64-linux-musl-static.5.3.1+relocatable.tar.gz
tar xf ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz
tar xf ocamlformat-x86_64-linux-musl-static.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz

DIR="$HOME/.alice/roots/5.3.1"
mkdir -p "$DIR"
cp -rvf ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
