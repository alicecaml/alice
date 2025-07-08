#!/bin/sh

docker buildx build --output type=local,dest=./out -f ubuntu.dockerfile .
mv out/ocaml.5.3.1+relocatable.tar.gz ./ocaml-linux-gnu.5.3.1+relocatable.tar.gz
rm -rf out
