#!/usr/bin/env python3
import hashlib
import json
import pathlib
import sys

prefix, cached, device = sys.argv[1:]
prefix, cached = pathlib.Path(prefix), pathlib.Path(cached)
manifest = json.loads((cached / f'share/openxc7/databases/{device}.json').read_text())
expected = dict(schema=1, architecture='any', byte_order='little', device=device,
                nextpnr=(prefix / 'share/licenses/nextpnr/source-commit').read_text().strip(),
                prjxray_db=(prefix / 'share/licenses/nextpnr/database-commit').read_text().strip())
for field, value in expected.items():
    if manifest.get(field) != value:
        raise SystemExit(f'Cached table mismatch: {device} {field}')
for suffix in ('bin', 'delay'):
    path = cached / f'share/chipdb/{device}.{suffix}'
    with path.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    if digest != manifest.get(f'{suffix}_sha256'):
        raise SystemExit(f'Cached table checksum mismatch: {device}.{suffix}')
