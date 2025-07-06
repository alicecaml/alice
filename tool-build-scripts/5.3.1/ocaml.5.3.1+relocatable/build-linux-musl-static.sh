#!/bin/sh
set -ex

docker buildx build --output type=local,dest=./out -f alpine.dockerfile .
mv out/ocaml.5.3.1+relocatable.tar.gz ./ocaml-linux-musl-static.5.3.1+relocatable.tar.gz
rm -rf out
