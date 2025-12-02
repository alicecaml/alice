FROM alpine:3.22.0 AS builder

RUN apk update && apk add \
    build-base \
    musl-dev \
    curl \
    wget \
    git \
    bash \
    ;

# Install the OCaml compiler (via alice)
RUN curl -fsSL curl -fsSL https://github.com/alicecaml/alice-install/releases/download/v4/install.sh | sh -s -- 0.3.0-alpha2 --global /usr --no-prompt --install-tools --no-update-shell-config --install-compiler-only

# Install Dune
RUN curl -4fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v3/install.sh | sh -s 3.20.2 --install-root /usr --no-update-shell-config

RUN adduser -D -G users -G wheel user
WORKDIR /home/user
COPY --chmod=0755 . alice
RUN chown -R user alice

USER user
WORKDIR alice

ENV DUNE_PROFILE=static
RUN dune build

RUN (git describe --exact-match --tags || git rev-parse HEAD) | cat > version.txt
RUN uname -m > arch.txt
RUN echo alice-$(cat version.txt)-$(cat arch.txt)-linux-musl-static > name.txt
RUN cp -rvL _build/install/default $(cat name.txt)
RUN chmod a+w $(cat name.txt)/bin/alice
RUN strip $(cat name.txt)/bin/alice
RUN chmod a-w $(cat name.txt)/bin/alice
RUN mkdir -p $(cat name.txt)/share/bash-completion/completions
RUN scripts/generate_minified_bash_completion_script.sh > $(cat name.txt)/share/bash-completion/completions/alice
RUN tar czf $(cat name.txt).tar.gz $(cat name.txt)
RUN dune clean

FROM scratch
COPY --from=builder /home/user/alice .
