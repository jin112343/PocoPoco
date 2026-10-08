#!/usr/bin/env python3
"""編み目の名前の訳（tool/l10n/stitches/<code>.json）を、アプリの翻訳ファイル
（assets/lang/<code>.json）の末尾に入れる。何度実行しても同じ結果になる。

日本語と英語はソース内の名前（nameJa / nameEn）をそのまま使うので対象外。"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
LANG = os.path.join(HERE, '..', '..', 'assets', 'lang')
src = json.load(open(os.path.join(HERE, 'stitches_en.json'), encoding='utf-8'))
missing = []
for name in sorted(os.listdir(LANG)):
    code = name[:-5]
    if not name.endswith('.json') or code in ('ja', 'en'):
        continue
    path = os.path.join(HERE, 'stitches', name)
    if not os.path.exists(path):
        missing.append(code)
        continue
    names = json.load(open(path, encoding='utf-8'))
    target = os.path.join(LANG, name)
    data = json.load(open(target, encoding='utf-8'))
    data = {k: v for k, v in data.items() if not k.startswith('sn_')}
    for key in src:
        data[key] = names[key]
    with open(target, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
if missing:
    print('no stitch names yet:', ' '.join(missing))
    sys.exit(1)
print('merged')
