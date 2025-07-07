FROM alpine:3.22.0 AS builder

RUN apk update && apk add \
    build-base \
    musl-dev \
    curl \
    wget \
    git \
    bash \
    ;

RUN adduser -D -G users -G wheel user
USER user
WORKDIR /home/user

# Install Dune
RUN curl -fsSL https://get.dune.build/install | sh

# Install the OCaml compiler
ENV COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-x86_64-linux-musl-static.5.3.1%2Brelocatable.tar.gz"
RUN wget $COMPILER_URL
RUN echo 0f052512674e626eb66d90c59e6c076361058ecb7c84098ee882b689de9dbdc1  ocaml-x86_64-linux-musl-static.5.3.1+relocatable.tar.gz | sha256sum -c
RUN tar xf ocaml-x86_64-linux-musl-static.5.3.1+relocatable.tar.gz
RUN cp -r ocaml.5.3.1+relocatable/* .local

RUN git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocaml-lsp
WORKDIR ocaml-lsp
ENV PATH=/home/user/.local/bin:$PATH
COPY statically-link.diff statically-link.diff
RUN patch -p1 < statically-link.diff
RUN dune build
RUN cp -rvL _build/install/default ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
RUN tar czf ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable

FROM scratch
COPY --from=builder /home/user/ocaml-lsp/ocamllsp-x86_64-linux-musl-static.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz .
