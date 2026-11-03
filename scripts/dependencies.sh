#!/bin/bash
set -euo pipefail
source /src/versions.env
jobs=${JOBS:-4}
mkdir -p /opt/sdk /opt/musl /tmp/deps
cd /tmp/deps
arch=$(uname -m)
case "$arch" in
    x86_64)
        sdk_url="https://github.com/cross-tools/musl-cross/releases/download/$SDK_VERSION/x86_64-unknown-linux-musl.tar.xz"
        bazel_arch=x86_64 ;;
    aarch64)
        sdk_url="https://github.com/Matrix3600/musl-cross/releases/download/$ARM64_SDK_VERSION/linux-arm64_aarch64-unknown-linux-musl.tar.xz"
        SDK_SHA256=$ARM64_SDK_SHA256
        bazel_arch=arm64 ;;
    *) echo "Unsupported build architecture: $arch" >&2; exit 1 ;;
esac
target=$arch-unknown-linux-musl
curl -fLSs --retry 3 "$sdk_url" -o sdk.tar.xz
echo "$SDK_SHA256  sdk.tar.xz" | sha256sum -c -
tar -xf sdk.tar.xz -C /opt/sdk --strip-components=1
export PATH=/opt/sdk/bin:$PATH
ln -s "$target-gcc" /opt/sdk/bin/musl-gcc
ln -s "$target-g++" /opt/sdk/bin/musl-g++
ln -s "$target-strip" /opt/sdk/bin/musl-strip
export CC=$target-gcc CXX=$target-g++
export AR=$target-ar RANLIB=$target-ranlib
git init zlib
git -C zlib fetch --depth 1 https://github.com/madler/zlib.git "$ZLIB_REV"
git -C zlib checkout --detach FETCH_HEAD
(cd zlib; ./configure --static --prefix=/opt/musl; make -j"$jobs"; make install)
curl -fLSs --retry 3 "https://github.com/boostorg/boost/releases/download/$BOOST_REV/$BOOST_REV-b2-nodocs.tar.xz" -o boost.tar.xz
echo "$BOOST_SHA256  boost.tar.xz" | sha256sum -c -
mkdir boost
tar -xf boost.tar.xz -C boost --strip-components=1
(cd boost; ./bootstrap.sh --with-libraries=program_options,iostreams,thread,filesystem,atomic,chrono,date_time,system
 echo "using gcc : musl : $CXX ;" > project-config.jam
 ./b2 -j"$jobs" toolset=gcc-musl variant=release link=static threading=multi \
     --with-program_options --with-iostreams --with-thread --with-filesystem \
     --with-atomic --with-chrono --with-date_time --with-system \
     -sZLIB_INCLUDE=/opt/musl/include -sZLIB_LIBPATH=/opt/musl/lib \
     -sNO_BZIP2=1 -sNO_LZMA=1 -sNO_ZSTD=1 --prefix=/opt/musl install)
git clone --depth 1 --branch "$GCC_REV" https://github.com/gcc-mirror/gcc.git gcc
mkdir gomp-build
(cd gomp-build; ../gcc/libgomp/configure --host="$target" \
    --prefix=/opt/musl --libdir=/opt/musl/lib --disable-shared --enable-static --disable-multilib
 make -j"$jobs"; make install)
cp gomp-build/omp.h /opt/sdk/lib/gcc/$target/16.2.0/include/
cp gomp-build/.libs/libgomp.a /opt/sdk/lib/gcc/$target/16.2.0/
cp gomp-build/libgomp.spec /opt/sdk/lib/gcc/$target/16.2.0/
mkdir -p /opt/musl/licenses
cp boost/LICENSE_1_0.txt /opt/musl/licenses/BOOST.txt
cp zlib/LICENSE /opt/musl/licenses/ZLIB.txt
cp gcc/COPYING.RUNTIME gcc/COPYING3 /opt/musl/licenses/
curl -fLSs --retry 3 https://git.musl-libc.org/cgit/musl/plain/COPYRIGHT?h=v1.2.6 -o /opt/musl/licenses/MUSL.txt
cat > probe.cc <<'CPP'
#include <omp.h>
#include <thread>
int main() {
    int value = 0;
    std::thread t([&] { value = 20; });
    t.join();
    #pragma omp parallel for reduction(+:value)
    for (int i = 0; i < 22; ++i) ++value;
    return value != 42;
}
CPP
"$CXX" -std=c++20 -static -pthread -fopenmp probe.cc -o probe
./probe
url="https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-linux-$bazel_arch"
curl -fLSs --retry 3 "$url" -o /usr/local/bin/bazel
curl -fLSs --retry 3 "$url.sha256" -o /tmp/bazel.sha256
echo "$(cut -d' ' -f1 /tmp/bazel.sha256)  /usr/local/bin/bazel" | sha256sum -c -
chmod +x /usr/local/bin/bazel
rm -rf /tmp/deps
