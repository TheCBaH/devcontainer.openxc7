#!/bin/bash
(cd assembler
 bazel --batch --output_user_root="$workspace/.cache/bazel" build //fpga:fpga-as -c opt --jobs="$jobs" --curses=no \
    --repository_cache="$workspace/.cache/bazel-repos" --disk_cache="$workspace/.cache/bazel-actions" \
    --repo_env=CC=/opt/sdk/bin/musl-g++ \
    --repo_env=CXX=/opt/sdk/bin/musl-g++ \
    --linkopt=-static --host_linkopt=-static --dynamic_mode=off \
    --features=-supports_dynamic_linker
 install -m755 bazel-bin/fpga/fpga-as "$prefix/bin/"
 external="$(bazel --batch --output_user_root="$workspace/.cache/bazel" info output_base)/external"
 for repo in abseil-cpp rapidjson; do
     licenses="$prefix/share/licenses/assembler/external/$repo"
     mkdir -p "$licenses"
     find -L "$external/$repo"[+~]* -maxdepth 1 -type f \( -iname '*license*' -o -iname '*copying*' \) \
         -exec cp {} "$licenses/" \;
     test -n "$(ls -A "$licenses")"
 done)
