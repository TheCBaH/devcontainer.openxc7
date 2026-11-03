#!/bin/bash
set -euo pipefail
family=$1
prefix="$PWD/runtime"
destination="$PWD/.cache/databases/$family"
export PATH="$prefix/bin:$PATH" XZ_OPT='-T2 -6e'
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$destination"
failed=()
mapfile -t devices < <(python3 -c 'import json,sys; print("\n".join(json.load(open("devices.json"))[sys.argv[1]]))' "$family")
for device in "${devices[@]}"; do
    data="$work/$device"
    mkdir -p "$data/share/chipdb" "$data/share/nextpnr/prjxray-db"
    cp -a "$prefix/share/nextpnr/prjxray-db/$family" "$data/share/nextpnr/prjxray-db/"
    cp "$prefix/share/nextpnr/prjxray-db/LICENSE" "$data/share/nextpnr/prjxray-db/"
    if [ -L "$data/share/nextpnr/prjxray-db/$family/timings" ]; then
        rm "$data/share/nextpnr/prjxray-db/$family/timings"
        cp -a "$prefix/share/nextpnr/prjxray-db/artix7/timings" "$data/share/nextpnr/prjxray-db/$family/timings"
    fi
    python3 - "$data" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]).resolve()
for path in root.rglob('*'):
    if path.is_symlink():
        target = path.resolve(strict=True)
        if not target.is_relative_to(root):
            raise SystemExit(f'External database symlink: {path} -> {target}')
PY
    python3 scripts/database-metadata.py "$prefix" "$data" "$family" "$device"
    cached="$work/cached-$device"
    archive="$PWD/cached-databases/$family/openxc7-data-$device.tar.xz"
    mkdir -p "$cached"
    if [ -f "$archive" ] && tar -xJf "$archive" -C "$cached" \
        "./share/chipdb/$device.bin" "./share/chipdb/$device.delay" \
        "./share/openxc7/databases/$device.json" \
        && python3 scripts/verify-tables.py "$prefix" "$cached" "$device"; then
        cp "$cached/share/chipdb/$device."{bin,delay} "$data/share/chipdb/"
        echo "Reusing verified tables for $device"
    else
        python3 "$prefix/share/nextpnr/himbaechel/uarch/xilinx/gen/xilinx_gen.py" \
            --xray "$prefix/share/nextpnr/prjxray-db/$family" --device "$device" --bba "$work/chipdb.bba"
        bbasm -l "$work/chipdb.bba" "$data/share/chipdb/$device.bin"
        rm "$work/chipdb.bba"
    fi
    if ! OPENXC7_PREFIX="$data" bash scripts/smoke-device.sh "$data/share/openxc7/databases/$device.env"; then
        failed+=("$device")
    fi
    python3 scripts/database-metadata.py "$prefix" "$data" "$family" "$device"
    tar -cJf "$destination/openxc7-data-$device.tar.xz" -C "$data" .
    cp "$data/share/openxc7/databases/$device.json" "$destination/data-$device.json"
    rm -rf "$data" "$cached"
done
if [ "${#failed[@]}" -gt 0 ]; then
    printf '%s\n' "${failed[@]}" > "$destination/FAILED-$family"
fi
(cd "$destination"; sha256sum *.tar.xz *.json > "SHA256SUMS-data-$family")
