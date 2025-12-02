#!/bin/sh

# Bootsrapping script for x86_64-linux-musl-static. Creates an alice environment similar
# to the one created by `alice tools install` which can be used to build alice.

set -eux

BASE_URL="https://github.com/alicecaml/alice-tools/releases/download/5.3.1+relocatable"
OCAML="ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo bc00d5cccc68cc1b4e7058ec53ad0f00846ecd1b1fb4a7b62e45b1b2b0dc9cb5  $OCAML.tar.gz | sha256sum -c
echo a630fe7ce411fae60683ca30066c9d6bc28add4c0053191381745b36e3ccd2db  $OCAMLLSP.tar.gz | sha256sum -c
echo 440718b9272f17a08f1b7d5a620400acb76d37e82cfc609880ce4d7253fc8d9e  $OCAMLFORMAT.tar.gz | sha256sum -c

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$HOME/.alice/roots/5.3.1+relocatable"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
