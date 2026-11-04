#!/bin/bash
# Downloads the pinned dependency sources for the native architecture into
# .deps, which the image build reads instead of the network.
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
case "$(uname -m)" in
    x86_64)
        arch=x86_64
        sdk_url="https://github.com/cross-tools/musl-cross/releases/download/$SDK_VERSION/x86_64-unknown-linux-musl.tar.xz"
        sdk_sha=$SDK_SHA256
        bazel_arch=x86_64 bazel_sha=$BAZEL_SHA256 ;;
    aarch64|arm64)
        arch=aarch64
        sdk_url="https://github.com/Matrix3600/musl-cross/releases/download/$ARM64_SDK_VERSION/linux-arm64_aarch64-unknown-linux-musl.tar.xz"
        sdk_sha=$ARM64_SDK_SHA256
        bazel_arch=arm64 bazel_sha=$ARM64_BAZEL_SHA256 ;;
    *) echo "Unsupported build architecture: $(uname -m)" >&2; exit 1 ;;
esac
mkdir -p .deps
cd .deps

fetch() {
    local file=$1 sha=$2 url=$3
    echo "$sha  $file" | sha256sum -c --status - 2>/dev/null && return
    curl -fLSs --retry 3 "$url" -o "$file.tmp"
    echo "$sha  $file.tmp" | sha256sum -c -
    mv "$file.tmp" "$file"
}

# Archives come from the pinned revision, so equal revisions give equal bytes.
git_archive() {
    local file=$1 url=$2 rev=$3; shift 3
    test -f "$file" && return
    local tmp
    tmp=$(mktemp -d)
    git init -q "$tmp"
    git -C "$tmp" fetch -q --depth 1 "$url" "$rev"
    git -C "$tmp" archive --format=tar FETCH_HEAD "$@" | gzip -9n > "$file.tmp"
    rm -rf "$tmp"
    mv "$file.tmp" "$file"
}

fetch "sdk-$arch.tar.xz" "$sdk_sha" "$sdk_url"
fetch boost.tar.xz "$BOOST_SHA256" \
    "https://github.com/boostorg/boost/releases/download/$BOOST_REV/$BOOST_REV-b2-nodocs.tar.xz"
fetch "bazel-$arch" "$bazel_sha" \
    "https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-linux-$bazel_arch"
fetch musl-COPYRIGHT "$MUSL_COPYRIGHT_SHA256" \
    "https://git.musl-libc.org/cgit/musl/plain/COPYRIGHT?h=$MUSL_REV"
git_archive zlib.tar.gz https://github.com/madler/zlib.git "$ZLIB_REV"
# Only what libgomp's configure and Makefile reach outside libgomp/.
git_archive gcc-libgomp.tar.gz https://github.com/gcc-mirror/gcc.git "refs/tags/$GCC_REV" \
    ':(glob)*' config contrib include libgomp \
    gcc/BASE-VER gcc/DATESTAMP gcc/DEV-PHASE gcc/doc/include
