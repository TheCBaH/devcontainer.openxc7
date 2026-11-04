# Static openXC7 toolchain

[![build](https://github.com/TheCBaH/devcontainer.openxc7/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/TheCBaH/devcontainer.openxc7/actions/workflows/build.yml)

Open-source FPGA flow for Xilinx 7-series parts as static musl executables
for Linux x86_64 and ARM64: Yosys (with ABC and Slang), nextpnr-himbaechel
and fpga-as, plus prebuilt device databases. Needs no Python, Java, compiler
or glibc at runtime, only a POSIX shell. Sources follow the pins from
[openXC7/toolchain-installer](https://github.com/openXC7/toolchain-installer).

## Install

Download from the [latest release](https://github.com/TheCBaH/devcontainer.openxc7/releases/latest)
and check it against its `SHA256SUMS`. Extract the tool archive for your CPU,
`openxc7-linux-x86_64-musl.tar.xz` or `openxc7-linux-aarch64-musl.tar.xz`,
and the `openxc7-data-<device>.tar.xz` archives you need into `/opt/openxc7`,
then add `/opt/openxc7/bin` to `PATH`. Debian images need `xz-utils` to
extract them. Keep tools and data from the same release.

Alternatively, use the runtime image, which includes the xc7a50t data
(Basys 3, Arty A7-35T):

```sh
docker run --rm -it ghcr.io/thecbah/devcontainer.openxc7:<release-tag>
```

## Use

```sh
nextpnr-himbaechel --device <part> \
  --chipdb /opt/openxc7/share/chipdb/<device>.bin \
  -o xdc=<file> -o fasm=<file>
```

Full Vivado Tcl is not supported by nextpnr's XDC reader.

## Devices

| Family | Precomputed devices |
| --- | --- |
| Artix-7 | xc7a50t (also Basys/Arty xc7a35t packages), xc7a100t, xc7a200t |
| Kintex-7 | xc7k70t, xc7k160t, xc7k325t, xc7k420t, xc7k480t |
| Spartan-7 | xc7s50 |
| Virtex-7 | xc7vx485t |
| Zynq-7000 | xc7z010, xc7z020, xc7z030, xc7z045, xc7z100 |

Each die gets a bitstream smoke test on both CPUs. Timing uses the
upstream default model, not speed-grade sign-off, and physical boards are
not tested. See [docs/build.md](docs/build.md) for the limits.

## Develop

* [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=1442429932)
* Then, inside the devcontainer:
  * `make submodule` initialize the pinned sources
  * `make build TOOL=nextpnr` build one tool

Build stages, caching, device data generation and the release process are
described in [docs/build.md](docs/build.md).

## License

This repository is [MIT](LICENSE). Tool archives carry the licenses of
their sources and statically linked dependencies under `share/licenses/`.
