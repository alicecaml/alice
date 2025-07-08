#!/bin/sh

# Bootsrapping script for aarch64-macos. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-aarch64-macos.5.3.1%2Brelocatable.tar.gz"
OCAMLLSP_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamllsp-aarch64-macos.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
OCAMLFORMAT_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamlformat-aarch64-macos.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$COMPILER_URL"
wget "$OCAMLLSP_URL"
wget "$OCAMLFORMAT_URL"

echo 5df182e10051f927a04f186092f34472a5a12d837ddb2531acbc2d4d2544e5d6  ocaml-aarch64-macos.5.3.1+relocatable.tar.gz | sha256sum -c
echo f3165deb01ff54f77628a0b7d83e78553c24705e20e2c3d240b591eb809f59a3  ocamllsp-aarch64-macos.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c
echo 24408bbd0206ad32d49ee75c3a63085c66c57c789ca38d14c71dda3555d2902f  ocamlformat-aarch64-macos.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c

tar xf ocaml-aarch64-macos.5.3.1+relocatable.tar.gz
tar xf ocamllsp-aarch64-macos.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz
tar xf ocamlformat-aarch64-macos.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz

DIR="$HOME/.alice/roots/5.3.1"
mkdir -p "$DIR"
cp -rvf ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
