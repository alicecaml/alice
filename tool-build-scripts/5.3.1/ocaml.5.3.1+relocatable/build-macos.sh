#!/bin/sh
set -e

arch=$(uname -m)
case "$arch" in
    arm64) arch=aarch64 ;;
    *) ;;
esac

TMP=$(mktemp -d)
echo $TMP
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"

cd "$TMP"
wget https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compiler-sources/ocaml-5.3.1+relocatable.tar.gz

tar xf ocaml-5.3.1+relocatable.tar.gz
cd ocaml-5.3.1+relocatable
./configure \
    --prefix=$TMP/ocaml-5.3.1+relocatable-$arch-macos \
    --with-relative-libdir=../lib/ocaml \
    --enable-runtime-search=always
make -j
make install
cd ..
tar czf ocaml-5.3.1+relocatable-$arch-macos.tar.gz ocaml-5.3.1+relocatable-$arch-macos
cp ocaml-5.3.1+relocatable-$arch-macos.tar.gz "$ORIGINAL_DIR/ocaml-5.3.1+relocatable-$arch-macos.tar.gz"
