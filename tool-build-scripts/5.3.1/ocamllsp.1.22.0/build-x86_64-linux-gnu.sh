#!/bin/sh
set -ex

docker buildx build --output type=local,dest=./out -f ubuntu-x86_64.dockerfile .
mv out/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz .
rm -rf out
