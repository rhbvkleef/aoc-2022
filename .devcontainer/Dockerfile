FROM docker.io/erlang:25-alpine

ADD https://github.com/gleam-lang/gleam/releases/download/v0.24.0/gleam-v0.24.0-x86_64-unknown-linux-musl.tar.gz /tmp/gleam.tar.gz
RUN cd /tmp && tar xvf gleam.tar.gz && rm gleam.tar.gz && mv gleam /usr/bin/gleam && chmod +x /usr/bin/gleam && apk add git zsh nodejs
ENV SHELL /bin/zsh

ENTRYPOINT zsh
