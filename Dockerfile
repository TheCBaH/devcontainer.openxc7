ARG DEPS_IMAGE
FROM ${DEPS_IMAGE} AS database-builder
ARG FAMILY
ARG TOOLS_ARCH
ARG SOURCE_COMMIT
ENV SOURCE_COMMIT=$SOURCE_COMMIT
COPY artifacts /src/artifacts
COPY devices.json /src/devices.json
COPY cached-databases /src/cached-databases
COPY scripts/build-databases.sh scripts/database-metadata.py scripts/verify-tables.py scripts/smoke-device.sh /src/scripts/
WORKDIR /src
RUN mkdir runtime && for tool in yosys nextpnr assembler; do \
    tar -xzf "artifacts/$tool-$TOOLS_ARCH/$tool.tar.gz" -C runtime; done
RUN bash scripts/build-databases.sh "$FAMILY" && mv ".cache/databases/$FAMILY" /database-dist

FROM scratch AS database-export
COPY --from=database-builder /database-dist/ /

FROM ${DEPS_IMAGE} AS builder
ARG SOURCE_COMMIT
ENV SOURCE_COMMIT=$SOURCE_COMMIT
COPY artifacts /src/artifacts
COPY LICENSE versions.env /src/
COPY scripts/package.sh /src/scripts/
WORKDIR /src
RUN bash scripts/package.sh

FROM scratch AS archive-export
COPY --from=builder /src/dist/ /

FROM debian:bookworm-slim AS runtime
COPY --from=builder /opt/openxc7 /opt/openxc7
ENV PATH=/opt/openxc7/bin:$PATH
ENV PRJXRAY_DB_DIR=/opt/openxc7/share/nextpnr/prjxray-db
ENV OPENXC7_CHIPDB=/opt/openxc7/share/chipdb
CMD ["/bin/sh"]
