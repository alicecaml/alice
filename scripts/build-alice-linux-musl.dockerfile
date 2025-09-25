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
RUN curl -4fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v3/install.sh | sh -s 3.20.2 --install-root /usr --no-update-shell-config

RUN adduser -D -G users -G wheel user
WORKDIR /home/user
COPY --chmod=0755 . alice
RUN chown -R user alice

USER user
WORKDIR alice

RUN awk '{ print } /\(executable/ { print " (link_flags (:standard -cclib -static))" }' alice/src/dune > /tmp/alice_static_dune && cp /tmp/alice_static_dune alice/src/dune
RUN dune build
RUN git describe --exact-match --tags || git rev-parse HEAD | cat > version.txt
RUN uname -m > arch.txt
RUN echo alice-$(cat version.txt)-$(cat arch.txt)-linux-musl-static > name.txt
RUN cp -rvL _build/install/default $(cat name.txt)
RUN chmod a+w $(cat name.txt)/bin/alice
RUN strip $(cat name.txt)/bin/alice
RUN chmod a-w $(cat name.txt)/bin/alice
RUN tar czf $(cat name.txt).tar.gz $(cat name.txt)

FROM scratch
COPY --from=builder /home/user/alice .
