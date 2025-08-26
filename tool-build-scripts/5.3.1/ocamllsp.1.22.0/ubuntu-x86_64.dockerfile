FROM ubuntu:noble-20250529 AS builder

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    bash \
    ;

# Install the OCaml compiler
ENV COMPILER_URL="https://s3.g.s4.mega.io/ycsnsngpe2elgjdd2uzbdpyj6s54q5itlvy6g/alice/tools/5.3.1/ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz"
RUN wget $COMPILER_URL
RUN echo 3a7d69e8a8650f4527382081f0cfece9edf7ae7e12f3eb38fbb3880549b2ca90  ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz | sha256sum -c
RUN tar xf ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz
RUN cp -r ocaml-5.3.1+relocatable-x86_64-linux-gnu/* /usr

# Install Dune
RUN curl -fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v2/install.sh | sh -s 3.20.0 --install-root /usr --no-update-shell-config

RUN useradd --create-home --gid users user
USER user
WORKDIR /home/user

RUN git clone --depth 1 --single-branch --branch 1.22.0-build-with-ocaml.5.3.1+relocatable https://github.com/alicecaml/ocaml-lsp
WORKDIR ocaml-lsp
ENV PATH=/home/user/.local/bin:$PATH
COPY statically-link.diff statically-link.diff
RUN patch -p1 < statically-link.diff
RUN dune build
RUN cp -rvL _build/install/default ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu
RUN tar czf ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu

FROM scratch
COPY --from=builder /home/user/ocaml-lsp/ocamllsp-1.22.0-built-with-ocaml-5.3.1+relocatable-x86_64-linux-gnu.tar.gz .
