# Static openXC7 toolchain

Development lives on `devel`; `main` intentionally contains only an empty
root commit.

Debian 13 hosts a pinned GCC 16 musl C/C++ SDK. All FPGA executables and
their C++ dependencies are built against musl, with static linking checked
using ELF program headers and dynamic sections. The SDK checksum and build
dependency versions are recorded in `versions.env`. FPGA sources and the
database are pinned as Git submodules, following the pins from
[openXC7/toolchain-installer](https://github.com/openXC7/toolchain-installer).

The targets are Linux x86_64 and ARM64, with device data for the five
Xilinx 7-series families supported by the pinned backend. Each architecture
builds and runs its checks on native GitHub runners with a separately cached
dependency image. Yosys includes ABC/abc9 and Slang; its static batch
profile excludes Tcl, readline, DPI-C and dynamically loaded plugins.
Nextpnr includes OpenMP; Boost compression supports zlib. The runtime needs
data files and a POSIX shell for Yosys subprocesses, but no Python, Java,
compiler or glibc.

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

The image build is staged. Each CI build runs inside the cached development
container and exports binary/source artifacts. Separate cached jobs generate
the chip and delay tables once per device, independently of the CPU
architecture. The root `Dockerfile` consumes the tool artifacts in its
`builder` stage and exports the architecture-specific tools. Its final
`runtime` stage starts from a fresh Debian image and copies only
`/opt/openxc7`; compilers, SDK, Python, Java and build trees stay in the
builder. CI publishes the runtime image after testing its archive offline
on Debian and Alpine. The same archive can be loaded into an OCaml project's
Docker image without rebuilding any FPGA tools.

Release tool archives contain executables and their technology files.
`openxc7-data-<device>.tar.xz` separately contains the matching Project
X-Ray family database, precomputed chip/delay tables and a device manifest
under `share/openxc7/databases/`. These archives are CPU-independent for
the two supported little-endian platforms. CI generates each once and
tests those exact bytes with both native toolchains, offline, non-root and
read-only on Debian and Alpine. One package per die gets a counter
bitstream smoke test; this does not validate every package, primitive or
physical board.
Smoke tests prefer HR-bank pins across packages where available. The pinned
engine/database pair cannot assemble some Zynq HP-bank input encodings;
the archives do not imply that every I/O standard and package is validated.
The z100 test selects a lower HR clock bank to avoid missing top-HROW
clock-input encodings. Candidate tables are cached even if a smoke test
fails, but the job still fails until every device passes.
Timing uses the upstream DEFAULT model, including Artix SDF fallback for
Kintex/Virtex, rather than speed-grade timing sign-off. The database's
absolute Virtex timing-data symlink is materialized in the archive; all
remaining symlinks must resolve within the extracted data.

| Family | Precomputed devices |
| --- | --- |
| Artix-7 | xc7a50t (also Basys/Arty xc7a35t packages), xc7a100t, xc7a200t |
| Kintex-7 | xc7k70t, xc7k160t, xc7k325t, xc7k420t, xc7k480t |
| Spartan-7 | xc7s50 |
| Virtex-7 | xc7vx485t |
| Zynq-7000 | xc7z010, xc7z020, xc7z030, xc7z045, xc7z100 |

`devices.json` tracks this list. Database cache keys include the pinned
nextpnr and Project X-Ray revisions, the Yosys and fpga-as revisions used by
the smoke tests, and the generator/packaging scripts. A nextpnr or database
change regenerates the tables. Other changes, and runs whose smoke tests
failed, restore older archives with the same table sources: bin/delay hashes
and format fields are checked before reusing their tables, then metadata is
refreshed and the device smoke test runs again. Failed runs are cached
under a separate key, so they are never treated as an exact hit. Bump the
`data-v1` cache namespace and manifest schema if the generator invocation or
table encoding changes.

Runtime OCI images include the xc7a50t data for Basys 3 and Arty A7-35T;
other devices remain optional downloads. All published tar archives use xz.
Checksums, source provenance and verification logs accompany the archives.
Tool archives also include this repository's MIT license.

To consume a validated release, pin the checksums from its
`SHA256SUMS`, then extract `openxc7-linux-x86_64-musl.tar.xz` (or
`openxc7-linux-aarch64-musl.tar.xz` on ARM64) and the desired
`openxc7-data-<device>.tar.xz` into `/opt/openxc7`. Add `/opt/openxc7/bin`
to `PATH`. Debian image download stages need `xz-utils` to extract them.
The tools' `manifest.json` and each device manifest identify the matching
source revisions. Keep tools and data from the same validated release.

Use `make submodule` to initialize all pinned sources, or
`make build TOOL=nextpnr` inside the builder container to build one tool.
The database and nextpnr must be validated together when either pin moves.
Use the native `nextpnr-himbaechel --device <part> --chipdb
/opt/openxc7/share/chipdb/<device>.bin -o xdc=<file> -o fasm=<file>`
interface.
Full Vivado Tcl is not supported by nextpnr's XDC reader.
