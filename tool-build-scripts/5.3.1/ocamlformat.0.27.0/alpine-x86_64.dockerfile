FROM alpine:3.22.0 AS builder

RUN apk update && apk add \
    build-base \
    musl-dev \
    curl \
    wget \
    git \
    bash \
    ;

# Install the OCaml compiler
ENV COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz"
RUN wget $COMPILER_URL
RUN echo bc00d5cccc68cc1b4e7058ec53ad0f00846ecd1b1fb4a7b62e45b1b2b0dc9cb5  ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz | sha256sum -c
RUN tar xf ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz
RUN cp -r ocaml-5.3.1+relocatable-x86_64-linux-musl-static/* /usr

# Install Dune
RUN curl -fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v2/install.sh | sh -s 3.20.0 --install-root /usr --no-update-shell-config

RUN adduser -D -G users -G wheel user
USER user
WORKDIR /home/user

RUN git clone --depth 1 --single-branch --branch 0.27.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocamlformat
WORKDIR ocamlformat
COPY statically-link.diff statically-link.diff
RUN patch -p1 < statically-link.diff
RUN dune build
RUN cp -rvL _build/install/default ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static
RUN tar czf ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static

FROM scratch
COPY --from=builder /home/user/ocamlformat/ocamlformat-0.27.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-musl-static.tar.gz .
