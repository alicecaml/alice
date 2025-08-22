#!/bin/sh
set -e

# This build script assumes msys64 is installed to its default location
export PATH="$PATH:/c/msys64/usr/bin:/c/msys64/mingw64/bin"

arch=$(uname -m)
case "$arch" in
    arm64) arch=aarch64 ;;
    *) ;;
esac

TMP=$(mktemp -d -p "$HOME/AppData/Local/Temp")
echo $TMP
trap 'rm -rf $TMP' EXIT

ORIGINAL_DIR="$PWD"

cd "$TMP"
wget https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compiler-sources/ocaml-5.3.1+relocatable.tar.gz

tar xf ocaml-5.3.1+relocatable.tar.gz
cd ocaml-5.3.1+relocatable
rm -r flexdll
git clone https://github.com/ocaml/flexdll
git -C flexdll checkout 3400287999afcdc737f35c1d0e1447c7d2ae5a83
sh configure \
    --prefix=$TMP/ocaml-5.3.1+relocatable-$arch-windows \
    --with-relative-libdir=../lib/ocaml \
    --enable-runtime-search=always \
    --build=x86_64-w64-mingw32 \
    --enable-imprecise-c99-float-ops
make -j
make install
cd ..
tar czf ocaml-5.3.1+relocatable-$arch-windows.tar.gz ocaml-5.3.1+relocatable-$arch-windows
cp ocaml-5.3.1+relocatable-$arch-windows.tar.gz "$ORIGINAL_DIR/ocaml-5.3.1+relocatable-$arch-windows.tar.gz"
