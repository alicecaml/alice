#!/bin/sh

# Bootsrapping script for aarch64-macos. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

BASE_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1"
OCAML="ocaml-5.3.1+relocatable-aarch64-macos"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-macos"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo 4e9b683dc39867dcd5452e25a154c2964cd02a992ca4d3da33a46a24b6cb2187  $OCAML.tar.gz | sha256sum -c
echo bbfcd59f655dd96eebfa3864f37fea3d751d557b7773a5445e6f75891bc03cd3  $OCAMLLSP.tar.gz | sha256sum -c
echo 555d460f1b9577fd74a361eb5675f840ad2a73a4237fb310b8d6bc169c0df90c  $OCAMLFORMAT.tar.gz | sha256sum -c

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$HOME/.alice/roots/5.3.1+relocatable"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
