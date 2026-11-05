# Top Rope Slam

Architecture: Tom Dyer.
Code and this README: Claude (Opus 5.5).
Name: Tom Dyer ("top rope", because it was going to hurt).

Top Rope Slam looks at a picture and says how to draw it, in SLAM Draw
words. Then it tests what it says: SLAM Draw draws the words again, and
Top Rope Slam counts the places that are the same colour as the picture.

## Run it

```
rexx top_rope.rex australia.png australia.words
```

```
rexx top_rope.rex hallway_plan.png hallway.words 768
```

The last number is the height I look at the picture at (360 if you do
not give it). More is slower and sees small things better, as writing.

It needs ooRexx 5 with rxmath, ImageMagick (`convert`, `identify`), and
`rsvg-convert` (or ImageMagick) for the test. `slam_draw.rex` must be in
the same folder.

## How it sees

1. **Colours.** A colour is one it sees in the middle of a part, where
   the four next places are the same. A place between two colours (at an
   edge) can be either.
2. **Parts.** Places of one colour that touch.
3. **An inner frame.** A long straight line where two or more colours
   stop at the background, with no colour going on over it, is the edge
   of a frame (as the canton of a flag). The shapes in it are cut there,
   and it says them as a picture of their own: `make seen part` ... `end`,
   then `draw seen part in from ... to ...`.
4. **Writing.** Small parts of one colour in a line, close together. It
   says where the writing is and how big. It can not read it: it says
   `saying ?`.
5. **From the top down.** A shape is on top when, if it is drawn, it
   covers only its own colour, and shapes taken off before. It takes that
   shape off and looks again. So a band under a cross is one band, not
   ten bits. Rules for this:
   - a part of an other colour that is not said yet, inside the shape,
     is on top of it: the shape waits;
   - a band or box that could go on to the frame, or to more of its own
     colour, under an other colour, waits for that colour;
   - a place inside a shape that is on top can not be seen, so a shape
     under it can not say that place;
   - the best shape is the one with the most new places of its own colour,
     times the part of it that is its own colour.
6. **Kinds.**
   - **star**: the length from the middle goes up and down N times. N is
     the strongest wave in the lengths (one term of a Fourier sum), and
     where that wave is high are the points: that gives the turn. Then it
     tries a few sizes and inner parts, and keeps the one that is most the
     same as the part.
   - **circle**: the length from the middle has no wave.
   - **box**: a part that fills its box; round corners from what is
     missing at the four corners; a box that is only an edge.
   - **band**: from a long straight side. The angle is the best line
     through the outline places of that side (level or upright when it is
     less than 0.6 degrees from it). Thick: in from the side to the last
     place of its colour. Long: each way to the last place of its colour,
     or on to the frame when all on the way is on top of it. A band must
     be 2.5 times as long as it is thick.
   - **shape**: last of all, a shape with straight sides round the part.
7. **Words.** Lengths are in units: the height of the picture is 1. A
   number near a plain fraction (up to twelfths) is said as the fraction.

## What it says about the test pictures

| Picture | Same colour after the test | What it found |
|---|---|---|
| Australian flag (SLAM Draw) | 99.97% | the Union Jack in the canton as a picture of its own; crosses `thick 1/5` and `1/3`, saltire about `1/5`, red diagonals `1/15`; stars `size 1/7 inner 4/9`, `3/10`, `1/12` |
| Australian flag (ChatGPT) | 99.93% | red diagonals in the middle of the white (no counterchange); Beta and Delta level; Epsilon above the centre |
| US flag | 99.94% | six bands across at 3/26 ... 23/26, thick about 1/13; the box `0.758 by 0.539`; 49 of 50 stars, `inner 3/8` |
| South African flag | 99.91% | green `thick 1/5`, white and gold `thick 1/15`, the fly bands `1/3` |
| Japanese flag | 100% | `circle red size 3/5 at 3/4 1/2` |
| Nice boxes | 99.38% | the shade boxes under the boxes, round corners |
| Hallway plan (768 high) | 98.95% | walls as bands under the doors, doors, floor, the arrow, and where the writing is |

## What it can not do now

- read writing;
- see a curve that is not a circle (an arc, a sickle);
- say a round box that is only an edge: it says four bands;
- it is slow: about a minute for a flag at 360 high.

## Reading the writing (added)

Architecture: Tom Dyer (the word hint, the jiggle and the V5V idea are his).
Code: Claude (Opus 5.5).

- **As V5V:** the writing is found in the small picture; then only those
  squares are fetched from the picture at its own size, and read
  (`glyphs.cls`).
- **The difference finder (as V5V):** when the two nearest chars are close,
  look only at the cells where those two chars differ (in the same font),
  at twice the fine-ness. Book photo text: 60.8% to 64.2% right.
- **Jiggle:** each square is read turned a few ways (0, 2, -2, 4, -4 for
  writing across; 90, 270, and near them, for writing up and down; 180
  only when upright reads badly). An other way must be clearly better
  (0.7 of the score) than the way writing is most often.
- **Lessons:** `top_rope_lessons.txt` counts, for each way, the times it
  read best, from sure readings only. The ways that won most are tried
  first next time.
- **What is writing:** glyphs very near (and 3 or more of them), or near
  and the word list knows half the words. Else the words say `saying ?`:
  not knowing is better than a word made up.
- **The word hint:** `WORD_HINT="rexx word_hint.rex <word list>"`.

| Picture | What it read |
|---|---|
| Hallway plan | 7 of 10 labels, all 7 right: "to living room", "front door", "door" (2), "room not known" (2), "you". Not read: "hall 1 m wide", "4 m" |
| Floor plan (screenshot of a small JPEG) | parts only ("Bedroorr", "lroom", "Are:"), and some short wrong words from furniture; 45 squares said as `?` |
