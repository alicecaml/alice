FROM ubuntu:noble-20250529 AS builder

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    bash \
    unzip \
    ;

# Install Opam. Don't use the apt package because it would interfere with alice's OCaml binary distribution.
RUN curl -fsSL https://opam.ocaml.org/install.sh > install_opam.sh && yes '' | sh install_opam.sh

RUN useradd --create-home --gid users user
WORKDIR /home/user
COPY --chmod=0755 . alice
RUN chown -R user alice

USER user
WORKDIR alice

RUN boot/aarch64-linux-gnu.sh

RUN opam init --disable-sandbox --auto-setup --bare

ENV PATH=/home/user/.alice/current/bin:$PATH

# There's no Dune binary distro available for aarch64 linux, so install it with Opam instead.
RUN opam switch create . --empty
RUN opam repo add alice git+https://github.com/alicecaml/alice-opam-repo --all-switches
RUN opam update
RUN opam install -y ocaml-system.5.3.1+relocatable dune
RUN opam exec dune build

RUN (git describe --exact-match --tags || git rev-parse HEAD) | cat > version.txt
RUN uname -m > arch.txt
RUN echo alice-$(cat version.txt)-$(cat arch.txt)-linux-gnu > name.txt
RUN cp -rvL _build/install/default $(cat name.txt)
RUN chmod a+w $(cat name.txt)/bin/alice
RUN strip $(cat name.txt)/bin/alice
RUN chmod a-w $(cat name.txt)/bin/alice
RUN mkdir -p $(cat name.txt)/share/bash-completion/completions
RUN opam exec scripts/generate_minified_bash_completion_script.sh > $(cat name.txt)/share/bash-completion/completions/alice
RUN cp -v extra/alice-bin/* $(cat name.txt)
RUN tar czf $(cat name.txt).tar.gz $(cat name.txt)
RUN opam exec dune clean

FROM scratch
COPY --from=builder /home/user/alice .
