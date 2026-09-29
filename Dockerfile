# syntax=docker/dockerfile:1
#
# The builder always runs on the build platform and cross-compiles a static
# musl binary for the target, rustc under QEMU emulation crashes (SIGSEGV).
FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.9.0 AS xx
#
FROM --platform=$BUILDPLATFORM rust:1.98.1-alpine3.23 AS builder
COPY --from=xx / /
ARG TARGETPLATFORM
#
# Install packages, native ones for the tests and target ones for the build
RUN apk --no-cache -U add clang lld musl-dev && \
    xx-apk --no-cache add musl-dev gcc
#
WORKDIR /opt/honeyaml
COPY . .
#
# Test on the build platform, then cross-compile for the target
RUN cargo test && \
    xx-cargo build --release --target-dir ./build && \
    cp ./build/$(xx-cargo --print-target-triple)/release/honeyaml /opt/honeyaml/honeyaml-bin && \
    xx-verify --static /opt/honeyaml/honeyaml-bin
#
FROM scratch
#
COPY --from=builder /opt/honeyaml/honeyaml-bin /opt/honeyaml/honeyaml
COPY --from=builder /opt/honeyaml/api.yml /opt/honeyaml/
#
STOPSIGNAL SIGINT
USER 2000:2000
WORKDIR /opt/honeyaml
CMD ["./honeyaml", "-d", "/opt/honeyaml/log"]
