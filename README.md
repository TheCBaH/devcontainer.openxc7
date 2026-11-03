# Static openXC7 toolchain

Development lives on `devel`; `main` intentionally contains only an empty
root commit.

Debian 13 hosts a pinned GCC 16 musl C/C++ SDK. All FPGA executables and
their C++ dependencies are built against musl, with static linking checked
using ELF program headers and dynamic sections. The SDK checksum and build
dependency versions are recorded in `versions.env`. FPGA sources and the
database are pinned as Git submodules, following the pins from
[openXC7/toolchain-installer](https://github.com/openXC7/toolchain-installer).

The targets are Linux x86_64 and ARM64. Each architecture builds and runs
its checks on native GitHub runners with a separately cached dependency
image. Yosys includes ABC/abc9 and Slang; its static batch profile excludes
Tcl, readline, DPI-C and dynamically loaded plugins. Nextpnr includes
OpenMP; Boost compression supports zlib.

The reusable `images.yml` job uses
`TheCBaH/devcontainer-action/devcontainer@v1` to publish/cache the Debian
dependency image. The `build.yml` jobs use that helper to consume the image
and build the pinned Yosys, nextpnr and fpga-as submodules independently.
Moving a source submodule does not change the dependency image. Compiler and
Bazel caches survive individual source build failures. Actions uses separate
`cmake-<tool>-<arch>` and `bazel-<tool>-<arch>` cache keys. CMake uses
`.cache/ccache`; Bazel uses `.cache/bazel-repos` and `.cache/bazel-actions`.
Yosys and nextpnr retain their upstream CMake builds. Prepared source
archives accompany tool artifacts. Each tool artifact carries the license
and notice files of its sources and statically linked dependencies under
`share/licenses/`. The development container contains the same build
dependencies; it does not rebuild the FPGA tools at startup.

Use `make submodule` to initialize all pinned sources, or
`make build TOOL=nextpnr` inside the builder container to build one tool.
