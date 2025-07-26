#!/bin/sh

arch=$(uname -m)
case "$arch" in
    arm64) arch=aarch64 ;;
    *) ;;
esac

docker buildx build --output type=local,dest=./out -f ubuntu.dockerfile .
mv out/ocaml-5.3.1+relocatable-$arch-linux-gnu.tar.gz ./ocaml-5.3.1+relocatable-$arch-linux-gnu.tar.gz
rm -rf out
