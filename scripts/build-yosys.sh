#!/bin/bash
cmake -S yosys -B "$build_dir" "${cmake_options[@]}" \
    -DBUILD_SHARED_LIBS=OFF -DYOSYS_ENABLE_UNIT_TESTS=OFF \
    -DYOSYS_WITHOUT_TCL=ON -DYOSYS_WITHOUT_READLINE=ON \
    -DYOSYS_WITHOUT_EDITLINE=ON -DYOSYS_WITHOUT_LIBFFI=ON \
    -DYOSYS_USE_BUNDLED_LIBS=ON -DCMAKE_DISABLE_FIND_PACKAGE_Dlfcn=ON \
    -DCMAKE_C_FLAGS=-I/opt/musl/include -DCMAKE_CXX_FLAGS=-I/opt/musl/include
cmake --build "$build_dir" --parallel "$jobs"
cmake --install "$build_dir" --strip
find "$prefix/bin" -mindepth 1 -maxdepth 1 ! -name yosys ! -name yosys-abc -delete
notices="$prefix/share/licenses/yosys/notices"
mkdir -p "$notices"
while read -r header first last; do
    sed -n "\|$first|,\|$last|p" "yosys/$header" > "$notices/${header//\//_}"
    grep -q "$last" "$notices/${header//\//_}"
done <<'NOTICES'
libs/flex/FlexLexer.h Copyright PURPOSE\.
libs/fst/fstapi.h Copyright \*/
libs/json11/json11.hpp Copyright \*/
libs/sha1/sha1.h Public.Domain \*/
NOTICES
cp yosys/libs/bigint/README "$notices/libs_bigint_README"
