# Phase 0: Builder
# =========================
FROM paritytech/ci-linux:1.71.0-bullseye as builder

# Install needed packages
RUN apt-get update && \
	apt-get install -yqq --no-install-recommends git openssh-client && \
	rm -rf /var/lib/apt/lists

# Install nightly Rust for WASM  & prepare folders
# RUN	rustup toolchain install nightly && \
#	rustup target add wasm32-unknown-unknown --toolchain nightly && \
#	rustup default nightly

# Clone & build node binary.
ARG AVAIL_TAG=v1.6.0
RUN \
	mkdir -p /da/state && \
	mkdir -p /da/keystore && \
	git clone -b $AVAIL_TAG --single-branch https://github.com/availproject/avail.git /da/src/ && \
	cd /da/src && \
	cargo build --release -p data-avail

# Install binaries 
RUN \ 
	mkdir -p /da/bin && \
	mv /da/src/misc/genesis /da && \
	mv /da/src/target/release/data-avail /da/bin && \
	# Clean src \
	rm -rf /da/src


# Phase 1: Binary deploy
# =========================
FROM debian:bullseye-slim

# Minimize the number of RUN commands and clean up in the same layer
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -r avail && \
    useradd --no-log-init -r -g avail avail

# Copy the built binary from the builder stage
COPY --chown=avail.avail --from=builder /da/bin/data-avail /da/bin/data-avail

# Opencontainers annotations
LABEL org.opencontainers.image.authors="The Avail Project Team" \
    org.opencontainers.image.url="https://www.availproject.org/" \
    org.opencontainers.image.documentation="https://github.com/availproject/avail-deployment#readme" \
    org.opencontainers.image.source="https://github.com/availproject/avail-deployment" \
    org.opencontainers.image.version="1.0.0" \
    org.opencontainers.image.revision="1" \
    org.opencontainers.image.vendor="The Avail Project" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.title="Avail Node" \
    org.opencontainers.image.description="Data Availability Docker Node"

# Set User and Working Directory
USER avail:avail
WORKDIR /da
VOLUME ["/tmp", "/da/state", "/da/keystore"]

# Entrypoint and CMD Configuration
ENTRYPOINT ["/da/bin/data-avail"]
CMD ["--base-path", "/da/state", "--keystore-path", "/da/keystore", "--offchain-worker=Always", "--enable-offchain-indexing=true"]
