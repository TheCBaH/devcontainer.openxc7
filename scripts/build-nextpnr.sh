#!/bin/bash
bba_dir="$build_dir-bba"
cmake -S nextpnr/bba -B "$bba_dir" "${cmake_options[@]}" -DBoost_DIR=/opt/musl/lib/cmake/Boost-1.90.0
cmake --build "$bba_dir" --parallel "$jobs"
cmake -S nextpnr -B "$build_dir" "${cmake_options[@]}" -DBBA_IMPORT="$bba_dir/bba-export.cmake" \
    -DARCH=himbaechel -DHIMBAECHEL_UARCH=xilinx -DSTATIC_BUILD=ON \
    -DHAVE_GLIBC=ON "-DCMAKE_EXE_LINKER_FLAGS=-static -L/opt/musl/lib" -DUSE_OPENMP=ON -DBUILD_GUI=OFF -DBUILD_PYTHON=OFF \
    -DHIMBAECHEL_PRJXRAY_DB="$PWD/prjxray-db" \
    -DHIMBAECHEL_XILINX_DEVICES= -DBoost_DIR=/opt/musl/lib/cmake/Boost-1.90.0
cmake --build "$build_dir" --parallel "$jobs"
cmake --install "$build_dir" --strip
install -m755 "$bba_dir/bbasm" "$prefix/bin/"
mkdir -p "$prefix/share/nextpnr/prjxray-db"
cp -a prjxray-db/{artix7,kintex7,spartan7,virtex7,zynq7} "$prefix/share/nextpnr/prjxray-db/"
cp prjxray-db/LICENSE "$prefix/share/nextpnr/prjxray-db/LICENSE"
mkdir -p "$prefix/share/nextpnr/himbaechel/uarch"
cp -a nextpnr/himbaechel/uarch/xilinx "$prefix/share/nextpnr/himbaechel/uarch/"
cp -a nextpnr/himbaechel/himbaechel_dbgen "$prefix/share/nextpnr/himbaechel/"
mkdir -p "$prefix/share/licenses/nextpnr/external/eigen"
cp /usr/share/doc/libeigen3-dev/copyright "$prefix/share/licenses/nextpnr/external/eigen/"
git -C prjxray-db rev-parse HEAD > "$prefix/share/licenses/nextpnr/database-commit"
