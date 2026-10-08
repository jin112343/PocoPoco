#!/usr/bin/env python3
"""翻訳ファイルの検査。usage: validate.py <code> [<code> ...]
assets/lang/<code>.json が、原文(source_en.json)と同じキー・同じプレースホルダーを持つか確かめる。"""
import json, re, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
LANG_DIR = os.path.join(HERE, '..', '..', 'assets', 'lang')
src = json.load(open(os.path.join(HERE, 'source_en.json'), encoding='utf-8'))
PH = re.compile(r'\{[a-zA-Z_]+\}')
# 訳さずにそのまま残してよいもの（固有名詞や記号だけの文言）
SAME_OK = {'ok', 'app_title'}
status = 0
for code in sys.argv[1:]:
    path = os.path.join(LANG_DIR, code + '.json')
    errors = []
    try:
        data = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        print(f'{code}: NG cannot read ({e})'); status = 1; continue
    missing = [k for k in src if k not in data]
    extra = [k for k in data if k not in src]
    if missing: errors.append(f'missing keys ({len(missing)}): {missing[:8]}')
    same = 0
    for k, v in src.items():
        t = data.get(k)
        if t is None: continue
        if not isinstance(t, str) or not t.strip():
            errors.append(f'{k}: empty'); continue
        if sorted(PH.findall(v)) != sorted(PH.findall(t)):
            errors.append(f'{k}: placeholders differ: source {sorted(PH.findall(v))} vs {sorted(PH.findall(t))}')
        if v.count('\n') != t.count('\n'):
            errors.append(f'{k}: line breaks differ: source {v.count(chr(10))} vs {t.count(chr(10))}')
        if t == v and k not in SAME_OK and len(v) > 12:
            same += 1
    if same > 12:
        errors.append(f'{same} long strings are identical to English (not translated?)')
    if errors:
        status = 1
        print(f'{code}: NG')
        for e in errors[:25]: print('   -', e)
    else:
        print(f'{code}: OK ({len(data)} keys)')
sys.exit(status)
