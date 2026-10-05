#!/usr/bin/env python3
"""Lists translation keys the Flutter code uses that are missing from the web locales + assets/mobile files."""
import json, re, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
core = os.path.join(root, 'packages/rizo_core/assets')

def flat(d, pre=''):
    out = set()
    for k, v in d.items():
        key = pre + k
        if isinstance(v, dict):
            out |= flat(v, key + '.')
        else:
            out.add(key)
    return out

def merged(code):
    web = json.load(open(f'{core}/locales/{code}.json'))
    extra = json.load(open(f'{core}/mobile/{code}.json'))
    return flat(web) | flat(extra)

keys = {c: merged(c) for c in ['uz', 'ru', 'en']}
def has(k, c):
    s = keys[c]
    return k in s or any(x.startswith(k + '_') for x in s) or any(x.startswith(k + '.') for x in s)

used = {}
dynamic = set()
for base, _, files in os.walk(root):
    if '/.dart_tool' in base or '/build' in base: continue
    for f in files:
        if not f.endswith('.dart'): continue
        p = os.path.join(base, f)
        text = open(p).read()
        for m in re.finditer(r"""\b(?:tr|context\.tr)\(\s*(['"])([^'"]+)\1""", text):
            k = m.group(2)
            if '$' in k: dynamic.add((k, p.replace(root + '/', '')))
            else: used.setdefault(k, p.replace(root + '/', ''))
missing = sorted(k for k in used if not all(has(k, c) for c in keys))
for k in missing:
    print(k, '<-', used[k], [c for c in keys if not has(k, c)])
print(f'{len(used)} keys used, {len(missing)} missing; dynamic: {len(dynamic)}', file=sys.stderr)
if '--dynamic' in sys.argv:
    for k, p in sorted(dynamic): print('DYN', k, p)
