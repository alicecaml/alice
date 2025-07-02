FROM ubuntu:noble-20250529 AS builder

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y \
    build-essential \
    wget \
    ;

RUN useradd --create-home --gid users user
USER user
WORKDIR /home/user

RUN wget https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compiler-sources/ocaml-relocatable-5.3.1.tar.gz
RUN tar xf ocaml-relocatable-5.3.1.tar.gz
WORKDIR /home/user/ocaml-relocatable-5.3.1

RUN ./configure \
    --prefix=/home/user/ocaml.5.3.1 \
    --with-relative-libdir=../lib/ocaml \
    --enable-runtime-search=always \
    ;

RUN make -j
RUN make install

WORKDIR /home/user
RUN tar czf ocaml.5.3.1.tar.gz ocaml.5.3.1

FROM scratch
COPY --from=builder /home/user/ocaml.5.3.1.tar.gz .
