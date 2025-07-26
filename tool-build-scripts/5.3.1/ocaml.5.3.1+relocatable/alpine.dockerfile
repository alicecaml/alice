FROM alpine:3.22.0 AS builder

RUN apk update && apk add \
    build-base \
    musl-dev \
    ;

RUN adduser -D -G users -G wheel user
USER user
WORKDIR /home/user

RUN wget https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compiler-sources/ocaml-5.3.1+relocatable.tar.gz
RUN tar xf ocaml-5.3.1+relocatable.tar.gz
WORKDIR /home/user/ocaml-5.3.1+relocatable

ENV CFLAGS=-static
ENV LDFLAGS=-static
RUN sh -c "./configure \
    --prefix=/home/user/ocaml-5.3.1+relocatable-$(uname -m)-linux-musl-static \
    --enable-shared=no \
    --with-relative-libdir=../lib/ocaml \
    --enable-runtime-search=always \
    ";

RUN make -j
RUN make install

WORKDIR /home/user
RUN sh -c "tar czf ocaml-5.3.1+relocatable-$(uname -m)-linux-musl-static.tar.gz ocaml-5.3.1+relocatable-$(uname -m)-linux-musl-static"

FROM scratch
COPY --from=builder /home/user/*.tar.gz .
