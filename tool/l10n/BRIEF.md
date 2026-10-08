# Translation brief: PocoPoco app strings

"PocoPoco" is a mobile app: a row and stitch counter for CROCHET (かぎ針編み). The user taps a stitch button
(chain, single crochet, double crochet…) to record each stitch, completes rows, saves projects, and can
subscribe to "Poco Premium" (unlimited saved projects, 60+ stitch buttons, no ads).

## Source files (read both first)
- English (translate this; 227 keys): /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/source_en.json
- Japanese original, for reference when the English is ambiguous: /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/source_ja.json

## Output
For each target language you are given, write /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/assets/lang/<file name> with:
- exactly the same 227 keys as source_en.json, in the same order; values translated; UTF-8; 2-space indent.
- Placeholders in curly braces ({count}, {row}, {price}, {plan}, {percent}, {n}, {current}, {total}, {remaining},
  {stitch}, {title}, {date}, {days}, {error}, {max}, {next}, {rows}, {version}) must appear UNCHANGED
  (same Latin names, same number of them). You may move them within the sentence. In right-to-left languages
  keep them exactly as `{name}`.
- Keep the same number of line breaks (\n) as the English value, and keep leading bullets like "• " or "・".
- Do NOT translate: "Poco Premium", "PocoPoco", "App Store", "Google Play", "TestFlight", "PDF".
- Natural, concise wording suitable for small mobile buttons and labels (short is better). Use the terms
  crocheters in that language really use for "row", "stitch", "chain stitch", "single crochet" etc.
  (common loanwords are fine where that is what people say). It is a crochet app, not a knitting-needle app.
  Friendly polite tone, consistent within the language.
- For the key "premium_price", translate the meaning "Monthly and yearly plans" (no currency amount).

## Validate
After writing each file run (code = file name without .json; several codes allowed):
python3 /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/validate.py <code>
Fix until it prints "OK" for every language.

## Rules
Do not create or modify any other files, and do not run git. Write each language file as soon as it is
translated (one file per Write), so finished languages are saved even if you are interrupted.
Final report: one line per language code with OK/NG, plus briefly any terms you were unsure about.
