#!/usr/bin/env python3
import csv
import hashlib
import json
import os
import pathlib
import sys

prefix, output, family, device = sys.argv[1:]
prefix, output = pathlib.Path(prefix), pathlib.Path(output)
database = prefix / 'share/nextpnr/prjxray-db' / family
parts = sorted(p.name for p in database.glob(f'{device}*-*') if p.is_dir())
# The pinned database cannot assemble some Zynq HP-bank input encodings,
# and z100's top HROW lacks some left clock-input bits.
LOW_CLOCK_BANK = {'xc7z100'}


def clock_rank(pin):
    return ('IOB33' not in pin['tile'], int(pin['bank']) if device in LOW_CLOCK_BANK else 0)


candidates = []
for part in parts:
    with (database / part / 'package_pins.csv').open() as source:
        pins = list(csv.DictReader(source))
    clocks = [p for p in pins if p['site'].startswith('IOB_')
              and 'MRCC' in p['pin_function'] and 'P_' in p['pin_function']]
    if not clocks:
        continue
    clock = min(clocks, key=clock_rank)
    outputs = [p for p in pins if p['site'].startswith('IOB_')
               and p['bank'] == clock['bank'] and p['pin'] != clock['pin']]
    if outputs:
        candidates.append(((clock_rank(clock), not part.endswith('-1'), part),
                           part, clock, outputs[0]))
if not candidates:
    raise SystemExit(f'No clock/output pin pair found for {device}')
_, part, clock, output_pin = min(candidates, key=lambda candidate: candidate[0])

metadata = output / 'share/openxc7/databases'
metadata.mkdir(parents=True, exist_ok=True)
settings = dict(DEVICE=device, FAMILY=family, PART=part,
                CLOCK_PIN=clock['pin'], OUTPUT_PIN=output_pin['pin'],
                IOSTANDARD='LVCMOS18')
(metadata / f'{device}.env').write_text(''.join(f'{k}={v}\n' for k, v in settings.items()))
manifest = dict(schema=1, architecture='any', byte_order='little', device=device,
                family=family, parts=parts, smoke=settings,
                timing_model='upstream DEFAULT (Artix SDF fallback for Kintex/Virtex)',
                producer_commit=os.environ.get('SOURCE_COMMIT'),
                nextpnr=(prefix / 'share/licenses/nextpnr/source-commit').read_text().strip(),
                prjxray_db=(prefix / 'share/licenses/nextpnr/database-commit').read_text().strip())
for suffix in ('bin', 'delay'):
    path = output / f'share/chipdb/{device}.{suffix}'
    if path.exists():
        manifest[f'{suffix}_sha256'] = hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()
(metadata / f'{device}.json').write_text(json.dumps(manifest, indent=2) + '\n')
