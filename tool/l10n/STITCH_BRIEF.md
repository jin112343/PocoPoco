# Translation brief: crochet stitch names for the PocoPoco app

PocoPoco is a row and stitch counter app for CROCHET. Each stitch button shows a chart symbol and the
stitch name below it in small text. You translate the 59 stitch names.

## Source (read both first)
- English (US crochet terms): /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/stitches_en.json
- Japanese original (the authoritative meaning; the English is a loose rendering):
  /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/stitches_ja.json

How to read the names (Japanese crochet chart conventions):
- "Double Crochet 3 Bobble" = 3-double-crochet bobble/cluster worked in one stitch (玉編み).
- "Special Bobble …" = puff-like bobble closed with an extra chain (変わり玉編み).
- "… 5 Popcorn" = popcorn stitch of 5 stitches. "Popcorn Stitch" (引き出し玉編み) = pulled-up puff stitch.
- "Single Crochet 2 Increase" = 2 single crochet in the same stitch (increase).
- "Single Crochet 2 Together" = single crochet 2 together (decrease, sc2tog).
- "Double Crochet Cross" = crossed double crochet (1 over 1); "Left Cross 3" = 1 double crochet crossed over 3, leaning left.
- "X-Stitch" = X-shaped crossed stitch. "5 Shell" = shell of 5 double crochet in one stitch.
- "Front/Back Post" = raised stitches around the post (FPdc/BPdc). "Back Loop Single Crochet" = sc in back loop only (すじ編み).
- "Wave Stitch" (うね編み) = ridge stitch: sc in back loop worked in rows. "Back Single Crochet" = reverse single crochet (crab stitch).
- "Twisted Single Crochet" = twisted sc. "Triple Crochet" (三つ巻き長編み) = double treble (yarn over 3 times);
  "Quadruple Crochet" (四つ巻き長編み) = triple treble (yarn over 4 times); "Treble Crochet" (長々編み) = US treble (yarn over twice).
- "Turning Chain" = turning chain at the start of a row. "Magic Ring" = adjustable ring start.
- "Chain-3 Picot (Slip Stitch)" = picot of 3 chains closed with a slip stitch; "(Single Crochet)" = closed with a single crochet.
- "Loop Stitch" = loop/fur stitch worked in sc or dc.

## Output
For each target language write /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/stitches/<code>.json
with exactly the same 59 keys in the same order, values = the stitch names in that language. UTF-8, 2-space indent.

- Use the names crocheters in that language really use in patterns and tutorials (e.g. French "maille serrée",
  German "feste Masche", Spanish "punto bajo", Russian "столбик без накида"). Where the community simply uses the
  English term or a loanword, use that. Where no established term exists, write a short, clear descriptive name
  built consistently from the basic stitch names you chose.
- All 59 names in a language must be distinct from each other and consistent (same word for the same base stitch).
- Keep them SHORT: they are button labels. Aim for 30 characters or fewer; hard limit 48. Prefer compact forms
  that are natural in the language; keep the digits.
- No trailing punctuation, no explanations, no abbreviations that only experts know (unless that abbreviation
  is the normal everyday name).

## Validate
python3 /Users/jin/Desktop/PocoPoco/.claude/worktrees/l10n-all-languages/tool/l10n/validate_stitches.py <code> [<code> ...]
Fix until it prints "OK" for every language.

## Rules
Do not create or modify any other files, and do not run git. Translate yourself (no machine-translation
services). Write each language file as soon as it is done (one file per Write), so finished languages are saved
even if you are interrupted. Final report: one line per code with OK/NG.
