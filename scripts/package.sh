#!/bin/bash
set -euo pipefail
arch=$(uname -m)
prefix=/opt/openxc7
export PATH="$prefix/bin:$PATH"
export NEXTPNR_XILINX_DIR="$prefix"
export PRJXRAY_DB_DIR="$prefix/share/nextpnr/prjxray-db"
export OPENXC7_CHIPDB="$prefix/share/chipdb"
export XZ_OPT='-T2 -6e'
mkdir -p "$prefix" dist
for tool in yosys nextpnr assembler; do
    tar -xzf "artifacts/$tool/$tool.tar.gz" -C "$prefix"
done
rm -rf "$prefix/share/nextpnr/himbaechel" "$prefix/share/nextpnr/prjxray-db" "$prefix/lib" "$prefix/include"
rm -f "$prefix/bin/yosys-config" "$prefix/bin/bbasm"
{
for binary in "$prefix"/bin/*; do
    readelf -h "$binary"
    if readelf -l "$binary" | grep -q INTERP || readelf -d "$binary" | grep -q NEEDED; then
        echo "Dynamic dependency in $binary" >&2
        exit 1
    fi
done
} | tee "dist/elf-$arch.txt"
python3 - "$prefix" <<'PY'
import json, os, pathlib, subprocess, sys
p = pathlib.Path(sys.argv[1])
pins = dict(line.split('=', 1) for line in pathlib.Path('versions.env').read_text().splitlines()
            if line.strip() and not line.startswith('#'))
sources = {f.parent.name: f.read_text().strip() for f in (p / 'share/licenses').glob('*/source-commit')}
sources['prjxray-db'] = (p / 'share/licenses/nextpnr/database-commit').read_text().strip()
manifest = dict(architecture=os.uname().machine, libc='musl', static=True, sources=sources,
                commit=os.environ.get('SOURCE_COMMIT') or subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                pins=pins, databases='separate openxc7-data-<device>.tar.xz archives',
                yosys_exclusions=['Tcl', 'readline', 'editline', 'DPI-C', 'dlopen plugins'])
(p / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
PY
mkdir -p "$prefix/share/licenses/openxc7"
cp LICENSE "$prefix/share/licenses/openxc7/"
tar -cJf dist/openxc7-linux-$arch-musl.tar.xz -C "$prefix" .
for source in artifacts/*/*-source.tar.gz; do
    name=$(basename "$source" .tar.gz)
    gzip -dc "$source" | xz -c > "dist/$name-$arch.tar.xz"
done
cp "$prefix/manifest.json" "dist/manifest-$arch.json"
(cd dist; sha256sum *.tar.xz *.json *.txt > "SHA256SUMS-$arch")
tar -xJf artifacts/database/openxc7-data-xc7a50t.tar.xz -C "$prefix"
