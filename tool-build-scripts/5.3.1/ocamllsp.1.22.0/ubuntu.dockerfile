FROM ubuntu:noble-20250529 AS builder

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    bash \
    ;

RUN useradd --create-home --gid users user
USER user
WORKDIR /home/user

# Install Dune
RUN curl -fsSL https://get.dune.build/install | sh

# Install the OCaml compiler
ENV COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-x86_64-linux-gnu.5.3.1%2Brelocatable.tar.gz"
RUN wget $COMPILER_URL
RUN echo 6044ea2cf088d83655f27b3844f6526f098610b591057c4c3de3af61bb4d338f  ocaml-x86_64-linux-gnu.5.3.1+relocatable.tar.gz | sha256sum -c
RUN tar xf ocaml-x86_64-linux-gnu.5.3.1+relocatable.tar.gz
RUN cp -r ocaml.5.3.1+relocatable/* .local

RUN git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocaml-lsp
WORKDIR ocaml-lsp
ENV PATH=/home/user/.local/bin:$PATH
RUN dune build
RUN cp -rvL _build/install/default ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable
RUN tar czf ocamllsp-x86_64-linux-gnu.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz ocamllsp.1.22.0-built-with-ocaml.5.3.1+relocatable

FROM scratch
COPY --from=builder /home/user/ocaml-lsp/ocamllsp-x86_64-linux-gnu.1.22.0-built-with-ocaml.5.3.1+relocatable.tar.gz .
