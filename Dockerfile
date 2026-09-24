# ==============================================================================
# NeighborNet Headless Community Relay Node Dockerfile
# Multi-stage lightweight build (~15MB final image)
# ==============================================================================

# Build Stage
FROM rust:1.80-slim-bullseye AS builder

WORKDIR /usr/src/neighbornet

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libsqlite3-dev \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

COPY neighbornet_core/ ./neighbornet_core/
COPY Cargo.toml Cargo.lock ./

WORKDIR /usr/src/neighbornet/neighbornet_core
RUN cargo build --release --bin neighbornet_node

# Runtime Stage
FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /usr/src/neighbornet/neighbornet_core/target/release/neighbornet_node /usr/local/bin/neighbornet_node

# Expose default Reticulum UDP broadcast port
EXPOSE 42424/udp

VOLUME ["/data"]

ENV PORT=42424
ENV NICKNAME=DockerRelay
ENV DATA_DIR=/data

ENTRYPOINT ["sh", "-c", "neighbornet_node --port ${PORT} --nickname ${NICKNAME} --data-dir ${DATA_DIR} --transport"]
