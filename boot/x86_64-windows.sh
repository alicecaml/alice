#!/bin/sh

# Bootsrapping script for x86_64-windows. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

ROOT="$1"

BASE_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1"
OCAML="ocaml-5.3.1+relocatable-x86_64-windows"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-windows"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo ed4256fa9aeb8ecaa846a58ee70d97d0519ec2878b5c5e2e0895e52a1796198e  $OCAML.tar.gz | sha256sum -c
echo fcce194c359656b0e507f252877f5874e5d0c598711b3079e2b8938991b714fe  $OCAMLLSP.tar.gz | sha256sum -c
echo 26b385b694cc1c03595ad91baac663a37f1e86faf57848d06e1d2dbc63bfefaf  $OCAMLFORMAT.tar.gz | sha256sum -c

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$ROOT/roots/5.3.1"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$ROOT/current"
