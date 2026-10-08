#!/usr/bin/env python3
"""編み目の名前（英語・日本語）をソースから取り出して、翻訳の原文 stitches_en.json / stitches_ja.json を作る。
キーは英語名から作る（lib/l10n/stitch_names.dart の stitchNameKey と同じ規則）。"""
import json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')

def key_for(name_en):
    return 'sn_' + re.sub(r'[^a-z0-9]+', '_', name_en.lower()).strip('_')

pairs = []
src = open(os.path.join(ROOT, 'lib/models/crochet_stitch.dart'), encoding='utf-8').read()
for m in re.finditer(r"\w+\(\s*'([^']+)',\s*'([^']+)',\s*'assets/images", src):
    pairs.append((m.group(1), m.group(2)))
src = open(os.path.join(ROOT, 'lib/models/premium_stitches.dart'), encoding='utf-8').read()
for m in re.finditer(r"'nameJa':\s*'([^']+)',\s*'nameEn':\s*'([^']+)'", src):
    pairs.append((m.group(1), m.group(2)))
en, ja = {}, {}
for name_ja, name_en in pairs:
    k = key_for(name_en)
    assert k not in en or en[k] == name_en, ('duplicate key', k)
    en[k] = name_en; ja[k] = name_ja
for name, data in (('stitches_en.json', en), ('stitches_ja.json', ja)):
    json.dump(data, open(os.path.join(HERE, name), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(len(pairs), 'stitches,', len(en), 'keys')
