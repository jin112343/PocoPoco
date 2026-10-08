#!/usr/bin/env python3
"""ストア文言の検査。usage: validate_store.py <code> [<code> ...]  (store/<code>.json を調べる)"""
import json, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
master = json.load(open(os.path.join(HERE, '_master_en.json'), encoding='utf-8'))
urls = json.load(open(os.path.join(HERE, '_urls.json')))
LIMITS = {'name': 30, 'subtitle': 30, 'keywords': 100, 'promotionalText': 170, 'playShort': 80,
          'description': 4000, 'whatsNew': 4000, 'cap1': 44, 'cap2': 44, 'cap3': 44, 'cap4': 44, 'cap5': 44}
status = 0
for code in sys.argv[1:]:
    path = os.path.join(HERE, code + '.json')
    errors = []
    try:
        data = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        print(f'{code}: NG cannot read ({e})'); status = 1; continue
    for key, limit in LIMITS.items():
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f'{key}: missing or empty'); continue
        if len(value) > limit:
            errors.append(f'{key}: {len(value)} characters, limit is {limit}')
    extra = [k for k in data if k not in LIMITS]
    if extra: errors.append(f'unexpected keys: {extra}')
    d = data.get('description') or ''
    for name in ('terms_url', 'privacy_url'):
        if urls[name] not in d: errors.append(f'description must contain the {name} unchanged')
    if 'PocoPoco' not in (data.get('name') or ''): errors.append('name must contain "PocoPoco"')
    if (data.get('keywords') or '').count(',') < 3: errors.append('keywords must be comma-separated (no spaces after commas)')
    if d.count('\n') < 20: errors.append('description lost its line breaks / list structure')
    if errors:
        status = 1; print(f'{code}: NG')
        for e in errors: print('   -', e)
    else:
        print(f'{code}: OK')
sys.exit(status)
