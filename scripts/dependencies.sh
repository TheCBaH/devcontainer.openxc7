#!/bin/bash
set -euo pipefail
source /src/versions.env
jobs=${JOBS:-4}
mkdir -p /opt/sdk /opt/musl /tmp/deps
cd /tmp/deps
arch=$(uname -m)
case "$arch" in
    x86_64) ;;
    aarch64) SDK_SHA256=$ARM64_SDK_SHA256 BAZEL_SHA256=$ARM64_BAZEL_SHA256 ;;
    *) echo "Unsupported build architecture: $arch" >&2; exit 1 ;;
esac
deps=/src/deps
target=$arch-unknown-linux-musl
echo "$SDK_SHA256  $deps/sdk-$arch.tar.xz" | sha256sum -c -
tar -xf "$deps/sdk-$arch.tar.xz" -C /opt/sdk --strip-components=1
export PATH=/opt/sdk/bin:$PATH
ln -s "$target-gcc" /opt/sdk/bin/musl-gcc
ln -s "$target-g++" /opt/sdk/bin/musl-g++
ln -s "$target-strip" /opt/sdk/bin/musl-strip
export CC=$target-gcc CXX=$target-g++
export AR=$target-ar RANLIB=$target-ranlib
mkdir zlib
tar -xzf "$deps/zlib.tar.gz" -C zlib
(cd zlib; ./configure --static --prefix=/opt/musl; make -j"$jobs"; make install)
echo "$BOOST_SHA256  $deps/boost.tar.xz" | sha256sum -c -
mkdir boost
tar -xf "$deps/boost.tar.xz" -C boost --strip-components=1
(cd boost; ./bootstrap.sh --with-libraries=program_options,iostreams,thread,filesystem,atomic,chrono,date_time,system
 echo "using gcc : musl : $CXX ;" > project-config.jam
 ./b2 -j"$jobs" toolset=gcc-musl variant=release link=static threading=multi \
     --with-program_options --with-iostreams --with-thread --with-filesystem \
     --with-atomic --with-chrono --with-date_time --with-system \
     -sZLIB_INCLUDE=/opt/musl/include -sZLIB_LIBPATH=/opt/musl/lib \
     -sNO_BZIP2=1 -sNO_LZMA=1 -sNO_ZSTD=1 --prefix=/opt/musl install)
mkdir gcc
tar -xzf "$deps/gcc-libgomp.tar.gz" -C gcc
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
echo "$MUSL_COPYRIGHT_SHA256  $deps/musl-COPYRIGHT" | sha256sum -c -
cp "$deps/musl-COPYRIGHT" /opt/musl/licenses/MUSL.txt
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
echo "$BAZEL_SHA256  $deps/bazel-$arch" | sha256sum -c -
install -m 755 "$deps/bazel-$arch" /usr/local/bin/bazel
rm -rf /tmp/deps
