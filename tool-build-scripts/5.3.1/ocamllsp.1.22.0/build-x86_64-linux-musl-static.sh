#!/bin/sh
set -ex

docker buildx build --output type=local,dest=./out -f alpine.dockerfile .
mv out/ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz ./ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz
rm -rf out
