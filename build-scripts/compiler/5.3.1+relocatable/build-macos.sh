#!/bin/sh
set -e

TMP=$(mktemp -d)
echo $TMP
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"

cd "$TMP"
wget https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/spice/compiler-sources/ocaml-relocatable-5.3.1.tar.gz
tar xf ocaml-relocatable-5.3.1.tar.gz
cd ocaml-relocatable-5.3.1
./configure \
    --prefix=$TMP/ocaml.5.3.1+relocatable \
    --with-relative-libdir=../lib/ocaml \
    --enable-runtime-search=always
make -j
make install
cd ..
tar czf ocaml.5.3.1+relocatable.tar.gz ocaml.5.3.1+relocatable
cp ocaml.5.3.1+relocatable.tar.gz "$ORIGINAL_DIR/ocaml-macos.5.3.1+relocatable.tar.gz"
