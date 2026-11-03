#!/bin/bash
set -euo pipefail
workspace=$(cd "$(dirname "$0")/.." && pwd)
source "$workspace/versions.env"
tool=$1
jobs=${JOBS:-4}
prefix="$workspace/.cache/install/$tool"
build_dir="$workspace/.cache/build/$tool"
rm -rf "$prefix"
mkdir -p "$prefix/bin" "$workspace/dist" "$build_dir"
export CCACHE_DIR="$workspace/.cache/ccache"
export CCACHE_BASEDIR="$workspace" CCACHE_COMPILERCHECK=content
ccache --max-size=2G
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$workspace" \
    GIT_CONFIG_KEY_1=safe.directory GIT_CONFIG_VALUE_1="$workspace/*"
cd "$workspace/sources"
cmake_options=(-G Ninja -DCMAKE_TOOLCHAIN_FILE=/opt/musl.cmake
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix"
    -DCMAKE_PREFIX_PATH=/opt/musl -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
source "$workspace/scripts/build-$tool.sh"
for binary in "$prefix"/bin/*; do
    file "$binary"
    if readelf -l "$binary" | grep -q INTERP || readelf -d "$binary" | grep -q NEEDED; then
        echo "Dynamic dependency in $binary" >&2
        exit 1
    fi
    musl-strip "$binary"
done
mkdir -p "$prefix/share/licenses/$tool"
cp -a /opt/musl/licenses "$prefix/share/licenses/$tool/dependencies"
find "$tool" -type d \( -name .git -o -name build \) -prune -o \
    -type f \( -iname '*license*' -o -iname '*copying*' -o -iname '*copyright*' \) \
    -exec cp --parents {} "$prefix/share/licenses/$tool/" \;
cp "$workspace/versions.env" "$prefix/share/licenses/$tool/versions.env"
git -C "$tool" rev-parse HEAD > "$prefix/share/licenses/$tool/source-commit"
git -C "$tool" submodule status --recursive > "$prefix/share/licenses/$tool/submodules"
"$CXX" --version > "$prefix/share/licenses/$tool/compiler.txt"
tar -czf "$workspace/dist/$tool.tar.gz" -C "$prefix" .
tar --exclude=.git --exclude='bazel-*' -czf "$workspace/dist/$tool-source.tar.gz" "$tool"
ccache --show-stats
