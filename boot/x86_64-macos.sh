#!/bin/sh

# Bootsrapping script for x86_64-macos. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

BASE_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1"
OCAML="ocaml-5.3.1+relocatable-x86_64-macos"
OCAMLLSP="ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos"
OCAMLFORMAT="ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-macos"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$BASE_URL/$OCAML.tar.gz"
wget "$BASE_URL/$OCAMLLSP.tar.gz"
wget "$BASE_URL/$OCAMLFORMAT.tar.gz"

echo 7d09047e53675cedddef604936d304807cfbe0052e4c4b56a2c7c05ac0c83304  $OCAML.tar.gz | sha256sum -c
echo f5483730fcf29acfdf98a99c561306fd95f8aebaac76a474c418365766365fc4  $OCAMLLSP.tar.gz | sha256sum -c
echo c3cdc14d1666e37197c5ff2e8a0a416b765b96b10aabe6b80b5aa3cf6b780339  $OCAMLFORMAT.tar.gz | sha256sum -c

tar xf "$OCAML.tar.gz"
tar xf "$OCAMLLSP.tar.gz"
tar xf "$OCAMLFORMAT.tar.gz"

DIR="$HOME/.alice/roots/5.3.1+relocatable"
mkdir -p "$DIR"
cp -rvf $OCAML/* "$DIR"
cp -rvf $OCAMLLSP/* "$DIR"
cp -rvf $OCAMLFORMAT/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
