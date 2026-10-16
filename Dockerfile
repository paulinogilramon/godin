# Builds the Linux artifacts (libgodin.so + app) in a reproducible container.
# Usage:  docker build -t godin-linux .   (or `godin docker-linux`)
#
# Odin cannot cross-link to Linux from Windows, so Linux artifacts are produced
# here (or on the CI ubuntu job) rather than via `odin -target:linux_amd64`.

ARG GO_VERSION=1.26
ARG ODIN_VERSION=dev-2026-10

FROM golang:${GO_VERSION}-bookworm AS odin

ARG ODIN_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl clang \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/odin-linux-amd64-${ODIN_VERSION}.tar.gz" -o /tmp/odin.tar.gz \
 && mkdir -p /opt/odin \
 && tar -xzf /tmp/odin.tar.gz -C /opt/odin --strip-components=1 \
 && rm /tmp/odin.tar.gz

ENV PATH="/opt/odin:${PATH}"

FROM odin AS build

WORKDIR /src
COPY . .

RUN mkdir -p build \
 && odin build odin -build-mode:shared -out:build/libgodin.so \
 && go build -C go -o ../build/app .
