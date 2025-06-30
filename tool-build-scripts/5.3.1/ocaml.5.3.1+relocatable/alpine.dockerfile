FROM alpine:3.22.0 AS builder

RUN apk update && apk add \
    build-base \
    musl-dev \
    ;

RUN adduser -D -G users -G wheel user
USER user
WORKDIR /home/user

RUN wget https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/compiler-sources/ocaml-relocatable-5.3.1.tar.gz
RUN tar xf ocaml-relocatable-5.3.1.tar.gz
WORKDIR /home/user/ocaml-relocatable-5.3.1

ENV CFLAGS=-static
ENV LDFLAGS=-static
RUN ./configure \
    --prefix=/home/user/ocaml.5.3.1 \
    --enable-shared=no \
    ;
RUN make -j
RUN make install

WORKDIR /home/user

RUN tar czf ocaml.5.3.1.tar.gz ocaml.5.3.1

FROM scratch
COPY --from=builder /home/user/ocaml.5.3.1.tar.gz .
