#!/bin/sh

# Bootsrapping script for x86_64-linux-gnu. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-x86_64-linux-gnu.5.3.1%2Brelocatable.tar.gz"
OCAMLLSP_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamllsp-x86_64-linux-gnu.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
OCAMLFORMAT_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamlformat-x86_64-linux-gnu.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$COMPILER_URL"
wget "$OCAMLLSP_URL"
wget "$OCAMLFORMAT_URL"

echo 6044ea2cf088d83655f27b3844f6526f098610b591057c4c3de3af61bb4d338f  ocaml-x86_64-linux-gnu.5.3.1+relocatable.tar.gz | sha256sum -c
echo 4be70889928acc75c09480306067514b4114fe68252fa0bdb7be9604ac7405de  ocamllsp-x86_64-linux-gnu.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c
echo 581b33a29c7f58d4e004021ca1dd1eb40e22555906e779de2ec6bd9def879318  ocamlformat-x86_64-linux-gnu.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c

tar xf ocaml-x86_64-linux-gnu.5.3.1+relocatable.tar.gz
tar xf ocamllsp-x86_64-linux-gnu.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz
tar xf ocamlformat-x86_64-linux-gnu.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz

DIR="$HOME/.alice/roots/5.3.1"
mkdir -p "$DIR"
cp -rvf ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
