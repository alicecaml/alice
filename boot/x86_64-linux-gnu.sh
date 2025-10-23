#!/bin/sh

# Bootsrapping script for x86_64-linux-gnu. Creates an alice environment similar
# to the one created by `alice tools install` which can be used to build alice.

set -eux

BASE_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1"
OCAML="ocaml-5.3.1+relocatable-x86_64-linux-gnu"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo 3a7d69e8a8650f4527382081f0cfece9edf7ae7e12f3eb38fbb3880549b2ca90  $OCAML.tar.gz | sha256sum -c
echo 0a7afeec4d7abf0e4c701ab75076a5ede2d25164260157e70970db4c4592ffab  $OCAMLLSP.tar.gz | sha256sum -c
echo 05ff3630ff2bed609ba062e85ecfdce0cf905124887cfb8b2544e489d0cbaf53  $OCAMLFORMAT.tar.gz | sha256sum -c

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$HOME/.alice/roots/5.3.1+relocatable"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
