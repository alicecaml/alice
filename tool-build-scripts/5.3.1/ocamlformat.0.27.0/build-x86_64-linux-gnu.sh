#!/bin/sh
set -ex

docker buildx build --output type=local,dest=./out -f ubuntu.dockerfile .
mv out/ocamlformat-x86_64-linux-gnu.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz ./ocamlformat-x86_64-linux-gnu.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz
rm -rf out
