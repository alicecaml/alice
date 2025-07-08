#!/bin/sh

# Bootsrapping script for x86_64-macos. Creates an alice environment similar
# to the one created by `alice tools get` which can be used to build alice.

set -eux

COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-x86_64-macos.5.3.1%2Brelocatable.tar.gz"
OCAMLLSP_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamllsp-x86_64-macos.1.22.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"
OCAMLFORMAT_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocamlformat-x86_64-macos.0.27.0-built-with-ocaml.5.3.1%2Brelocatable.tar.gz"

TMP=$(mktemp -d -t alice.XXXXXX)
trap 'rm -rf $TMP' EXIT

cd "$TMP"

wget "$COMPILER_URL"
wget "$OCAMLLSP_URL"
wget "$OCAMLFORMAT_URL"

echo 993bd258d2b26979888d8c52960115b64b060056b6d17cdf442e8f7d0ff47fbf  ocaml-x86_64-macos.5.3.1+relocatable.tar.gz | sha256sum -c
echo be35dfd1299aeb286995287734e7a5ec09d00d41194c3e795b437942758ddf47  ocamllsp-x86_64-macos.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c
echo 1c7a27c36fa8f97866990cea3e228f457d5bf0caae623e0b498b8132233897ff  ocamlformat-x86_64-macos.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz | sha256sum -c

tar xf ocaml-x86_64-macos.5.3.1+relocatable.tar.gz
tar xf ocamllsp-x86_64-macos.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz
tar xf ocamlformat-x86_64-macos.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz

DIR="$HOME/.alice/roots/5.3.1"
mkdir -p "$DIR"
cp -rvf ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"
cp -rvf ocamlformat.0.27.0-built-with-ocaml.5.3.1+relocatable/* "$DIR"

ln -sf "$DIR" "$HOME/.alice/current"
