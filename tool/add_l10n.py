#!/usr/bin/env python3
"""Merge new localization keys into app_en.arb (template) and app_tr.arb.

Usage: tool/add_l10n.py keys.json
keys.json: {"key": {"en": "...", "tr": "...", "desc": "...", "placeholders": {"count": {"type": "int"}}}}
Existing keys are overwritten so the script is idempotent.
"""
import json, sys, collections, pathlib

root = pathlib.Path(__file__).resolve().parent.parent / 'app' / 'lib' / 'l10n'

def load(p):
    return json.loads(p.read_text(encoding='utf-8'), object_pairs_hook=collections.OrderedDict)

def save(p, d):
    p.write_text(json.dumps(d, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')

keys = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
en = load(root / 'app_en.arb'); tr = load(root / 'app_tr.arb')
for k, v in keys.items():
    en[k] = v['en']
    meta = {'description': v.get('desc', '')}
    if 'placeholders' in v:
        meta['placeholders'] = v['placeholders']
    en['@' + k] = meta
    tr[k] = v.get('tr', v['en'])
save(root / 'app_en.arb', en); save(root / 'app_tr.arb', tr)
print(f'merged {len(keys)} keys')
