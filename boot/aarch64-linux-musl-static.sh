#!/bin/sh

# Bootsrapping script for aarch64-linux-musl-static. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

BASE_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1"
OCAML="ocaml-5.3.1+relocatable-aarch64-linux-musl-static"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-musl-static"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-musl-static"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo 661463be46580dd00285bef75b4d6311f2095c7deae8584667f9d76ed869276e  $OCAML.tar.gz | sha256sum -c -
echo 522880c7800230d62b89820419ec21e364f72d54ed560eb0920d55338438cacf  $OCAMLLSP.tar.gz | sha256sum -c -
echo 3cba0bfa0f075f3ab4f01752d18dd5dbbec03e50153892fdb83bc6b55b8e5f0e  $OCAMLFORMAT.tar.gz | sha256sum -c -

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$HOME/.alice/roots/5.3.1+relocatable"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
