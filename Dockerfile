# syntax=docker/dockerfile:1
#
# talkkonnect Dockerfile — ARM targets only (linux/arm64, linux/arm/v7)
#
# x86 (amd64/386) is excluded because github.com/talkkonnect/gopus bundles
# opus 1.3.1 C sources for x86 via opus_nonshared.go, but the bundled config.h
# was generated for ARM. This causes linker errors (undefined opus_select_arch,
# celt_fatal) when building on x86. On ARM, gopus instead links against the
# system libopus via pkg-config (opus_shared.go), which works correctly.
#
# Build for Raspberry Pi 3/4/5 (64-bit):  --platform linux/arm64
# Build for Raspberry Pi 2/3   (32-bit):  --platform linux/arm/v7

# ─── Build stage ─────────────────────────────────────────────────────────────
FROM docker.io/library/golang:1.24-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        libopenal-dev \
        libopus-dev \
        libasound2-dev \
        pkg-config \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Cache dependency downloads separately from source
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -ldflags="-s -w" -o /talkkonnect ./cmd/talkkonnect/main.go

# ─── Runtime stage ────────────────────────────────────────────────────────────
FROM docker.io/library/debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libopenal1 \
        libopus0 \
        libasound2 \
        ffmpeg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /talkkonnect /usr/local/bin/talkkonnect

# Bundle default sound files
COPY soundfiles/ /etc/talkkonnect/soundfiles/

# Config is supplied at runtime via a bind mount or volume
VOLUME ["/config"]

ENTRYPOINT ["talkkonnect", "-config", "/config/talkkonnect.xml"]
