#!/bin/sh
set -ex

arch=$(uname -m)
case "$arch" in
    arm64) arch=aarch64 ;;
    *) ;;
esac

docker buildx build --output type=local,dest=./out -f alpine.dockerfile .
mv out/ocaml-5.3.1+relocatable.tar.gz ./ocaml-5.3.1+relocatable-$arch-linux-musl-static.tar.gz
rm -rf out
