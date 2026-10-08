#!/usr/bin/env python3
"""編み目の名前の翻訳を検査する。usage: validate_stitches.py <code> [<code> ...]"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
src = json.load(open(os.path.join(HERE, 'stitches_en.json'), encoding='utf-8'))
status = 0
for code in sys.argv[1:]:
    errors = []
    try:
        data = json.load(open(os.path.join(HERE, 'stitches', code + '.json'), encoding='utf-8'))
    except Exception as e:
        print(f'{code}: NG cannot read ({e})'); status = 1; continue
    if list(data.keys()) != list(src.keys()):
        missing = [k for k in src if k not in data]; extra = [k for k in data if k not in src]
        errors.append(f'keys differ: missing {missing[:6]} extra {extra[:6]}' if missing or extra else 'key order differs')
    seen = {}
    for k, v in data.items():
        if not isinstance(v, str) or not v.strip(): errors.append(f'{k}: empty'); continue
        if v != v.strip() or '\n' in v: errors.append(f'{k}: stray whitespace')
        if len(v) > 48: errors.append(f'{k}: {len(v)} characters (limit 48): {v}')
        if v in seen: errors.append(f'{k}: same name as {seen[v]}: {v}')
        seen[v] = k
    same = sum(1 for k in src if data.get(k) == src[k])
    if same > 40: errors.append(f'{same} names identical to English (not translated?)')
    if errors:
        status = 1; print(f'{code}: NG')
        for e in errors[:20]: print('   -', e)
    else:
        longest = max(len(v) for v in data.values())
        print(f'{code}: OK (longest {longest})')
sys.exit(status)
