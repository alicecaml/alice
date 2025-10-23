#!/bin/sh

# Bootsrapping script for aarch64-linux-gnu. Creates an alice environment similar
# to the one created by `alice tools install` which can be used to build alice.

set -eux

BASE_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1"
OCAML="ocaml-5.3.1+relocatable-aarch64-linux-gnu"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-gnu"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-aarch64-linux-gnu"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo c89f1fc2a34222a95984a05e823a032f5c5e7d6917444685d88e837b6744491a  $OCAML.tar.gz | sha256sum -c -
echo 05ee153f176fbf077166fe637136fc679edd64a0942b8a74e8ac77878ac25d3f  $OCAMLLSP.tar.gz | sha256sum -c -
echo 28bceaceeb6055fada11cf3ba1dcc3ffec4997925dee096a736fdaef4d370e56  $OCAMLFORMAT.tar.gz | sha256sum -c -

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$HOME/.alice/roots/5.3.1+relocatable"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
