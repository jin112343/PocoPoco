# Translation brief: PocoPoco store listing

"PocoPoco" is a mobile app: a row and stitch counter for CROCHET (かぎ針編み). Users tap a stitch button for every
stitch; the app records rows, stitches and stitch types, saves multiple projects, and offers a "Poco Premium"
subscription.

## Source
English master: /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/store/_master_en.json
Fields: name, subtitle, keywords, promotionalText, playShort, description, whatsNew, cap1..cap5
(cap* are short headlines printed on screenshots).

## Output
For each locale you are given, write a JSON file with the SAME 12 fields, translated/adapted, to
/Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/store/<code>.json

Hard limits (characters, Python len()):
- name ≤ 30, must contain the brand "PocoPoco" (Latin letters) plus a localized descriptor meaning
  "crochet counter" (shorten the descriptor if needed)
- subtitle ≤ 30
- keywords ≤ 100 in total, comma-separated with NO spaces after commas; search terms crocheters/knitters would
  type in that language; do not repeat words already in the name
- promotionalText ≤ 170; playShort ≤ 80
- description ≤ 4000; keep the same structure (paragraphs, section headings, bullet lines starting with "• ",
  same number of bullets); keep the two URLs exactly, each on its own line after the translated
  "Terms of Use:" / "Privacy Policy:" labels
- whatsNew: keep the 5 bullet lines
- cap1..cap5 ≤ 44 each, punchy headline style
Do NOT translate "PocoPoco", "Poco Premium", "PDF". Write natural copy a native speaker would write, using the
crochet terminology people actually use (loanwords are fine where that is what people say). Do not invent
features or prices. Keep US stitch names (single/double crochet) for English variants.

## Validate
python3 /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/store/validate_store.py <code> [<code> ...]
Fix until every locale prints "OK".

## Rules
Do not modify any other files, and do not run git. Write each locale file as soon as it is done (one file
per Write), so finished locales are saved even if you are interrupted.
Final report: one line per locale code with OK/NG and the final `name`.
