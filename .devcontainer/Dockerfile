FROM debian:trixie AS base
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates curl xz-utils cmake ninja-build \
    pkg-config bison flex gawk python3 libeigen3-dev autoconf automake libtool \
    default-jdk-headless file ccache rsync && rm -rf /var/lib/apt/lists/*
FROM base AS dependency-builder
COPY versions.env /src/versions.env
COPY scripts/dependencies.sh /src/dependencies.sh
COPY .deps /src/deps
RUN bash /src/dependencies.sh
FROM base AS deps
COPY --from=dependency-builder /opt/sdk /opt/sdk
COPY --from=dependency-builder /opt/musl /opt/musl
COPY --from=dependency-builder /usr/local/bin/bazel /usr/local/bin/bazel
ENV PATH=/opt/sdk/bin:/opt/openxc7/bin:$PATH
ENV CC=musl-gcc CXX=musl-g++
ENV PKG_CONFIG_LIBDIR=/opt/musl/lib/pkgconfig
COPY cmake/musl.cmake /opt/musl.cmake
