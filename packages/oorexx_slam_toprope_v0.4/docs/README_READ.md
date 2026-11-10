# Reading writing (Top Rope Slam, first steps)

Architecture: Tom Dyer (the word hint call is his design).
Code and this README: Claude (Opus 5.5).

## The parts

| File | What it does |
|---|---|
| `glyphs.cls` | sees the glyphs (letters) in a part of a picture, gives each one its numbers, and finds the nearest glyphs learned before |
| `train_glyphs.rex` | learns 76 chars in 6 fonts and 3 sizes: `glyphs.txt` (1,368 glyphs) |
| `word_hint.rex` | the word hint: an other program, given the near chars of each word, and lists of words |
| `read_page.rex` | reads the lines of a page (a photo too), with the hint, and counts the chars that are right |
| `test_glyphs.rex` | reads lines in sizes the training did not see, with and without the hint |

Fonts learned: Liberation Sans (as Arial), Liberation Serif (as Times),
Liberation Mono (as Courier), DejaVu Sans, DejaVu Serif, Carlito (as Calibri).
Upright only: no turn and no slope are learned (not yet).

## How a glyph is said

A grid of 8 across and 12 down, how dark each cell is (0 to 9), how wide
the glyph is, and where its top and bottom are from the line the letters
sit on. All are parts of the height of a capital, so the size does not
matter. The dot of an i goes with its stem. Two glyphs that touch: a wide
glyph that is not near any one glyph is cut at the column with the least
ink, if the two parts are nearer.

## The word hint

The hint does not make a word. For each glyph, it can only choose
between chars that are near the best: not more than 1.6 times as far
(or 0.02 more), and not more than 0.05 more in all. And it may change at
most a third of the glyphs of a word. Words of one char, and words with
no letter, are not hinted. So `1itera11y` can be `literally`, but `Qzx7`
stays `Qzx7`, and a word read badly all through is not made into an
other word.

## Run it

```
rexx train_glyphs.rex
```

```
WORD_HINT="rexx word_hint.rex /usr/share/dict/american-english" rexx test_glyphs.rex
```

```
WORD_HINT="rexx word_hint.rex /usr/share/dict/american-english" rexx read_page.rex body.png 50 body_truth.txt
```

`read_page.rex` needs ImageMagick. The word list is any file with one
word a line (on Ubuntu: the `wamerican` package).

## What it does now

| Test | Without the hint | With the hint |
|---|---|---|
| 6 fonts, sizes not learned (1,428 chars) | 87.5% | 87.8%, and no word that is not in the list was changed |
| Book photo, heading (a slab serif, not learned) | 97.9% | 97.9% |
| Book photo, text (an old serif, as Garamond, not learned) | 60.8% | 63.5% |

## What it can not do now

- serif fonts it did not learn are hard (the old serif of the book: e and c, a and u);
- the "fi" made as one glyph (a ligature);
- the space between words in a line made the same width at both ends (justified);
- writing that is turned, or slopes (italic);
- it is not in `top_rope.rex` yet: there, writing is still `saying ?`.
