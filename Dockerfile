FROM golang:alpine3.24 AS builder

# hadolint ignore=DL3018
RUN apk add --no-cache gcc musl-dev git

WORKDIR ${GOPATH}/src/github.com/jpfox156/ofelia

COPY go.mod go.sum ./
RUN go mod download

COPY . ${GOPATH}/src/github.com/jpfox156/ofelia

RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /go/bin/ofelia .

# Runtime stage
FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

# OCI Image Annotations
# See: https://github.com/opencontainers/image-spec/blob/main/annotations.md
# Dynamic labels (created, version, revision) are added by docker/metadata-action in CI
LABEL org.opencontainers.image.title="Ofelia" \
      org.opencontainers.image.description="A docker job scheduler (based on mcuadros/ofelia)" \
      org.opencontainers.image.url="https://github.com/netresearch/ofelia" \
      org.opencontainers.image.documentation="https://github.com/netresearch/ofelia#readme" \
      org.opencontainers.image.source="https://github.com/netresearch/ofelia" \
      org.opencontainers.image.vendor="Netresearch DTT GmbH" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="Netresearch DTT GmbH <info@netresearch.de>" \
      org.opencontainers.image.base.name="alpine:3.23"

# This label is required to identify container with ofelia running
LABEL ofelia.service=true \
      ofelia.enabled=true

# tini is used as init process (PID 1) to properly reap zombie processes
# from local jobs. See: https://github.com/krallin/tini
# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates tini tzdata

COPY --from=builder /go/bin/ofelia /usr/bin/ofelia

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD pgrep ofelia >/dev/null || exit 1

# Use tini as init to handle zombie process reaping
# The -g flag ensures tini kills the entire process group on signal
ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/bin/ofelia"]

CMD ["daemon", "--config", "/etc/ofelia/config.ini"]
