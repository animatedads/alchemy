# SLAM Draw

Architecture: Tom Dyer.
Code and this README: Claude (Opus 5.5).

SLAM Draw makes a picture from simple words.
It reads lines. Each line is one thing to draw.
It writes an SVG file.

It does not guess. If it does not know a word, it stops,
and it says the word and the line.

## Run it

```
rexx slam_draw.rex actually draw an australian flag australia.svg
```

```
rexx slam_draw.rex draw some nice boxes boxes.svg
```

```
rexx slam_draw.rex my_picture.words my_picture.svg
```

```
rexx slam_draw.rex words
```

You can give a file of lines, or lines split with `;`.
If the last word ends in `.svg`, that is the file to write.
It needs ooRexx 5 and the rxmath library that comes with it.

## The words

These words are skipped: `a an the some please actually`.
Big and small letters are the same. A note starts with `--`.

| Line starts with | What it does | Example |
|---|---|---|
| `size` | the shape of the picture, in units | `size 2 by 1` |
| `page` | the size of the file, in dots | `page 1200 wide` |
| `colour` | gives a name to a colour | `colour navy is #012169` |
| `paint` | fills all the picture | `paint all navy` |
| `box` | a box | `box red from 0 0 to 1 1 round 0.1` |
| `band` | a straight band | `band white across at 1/2 thick 1/3` |
| `star` | a star | `star 7 points white size 3/10 inner 4/9 at middle` |
| `circle` | a circle | `circle red size 6/5 at middle` |
| `shape` | a shape with straight sides | `shape black from 0 0 to 1 1 to 0 2` |
| `mark` | gives a name to a place | `mark fly at 3/2 1/2` |
| `draw` | draws a picture from the book | `draw union flag in canton` |
| `make` ... `end` | puts a new picture in the book | see `pictures.words` |

### Numbers

`2`, `0.5`, `3/10`, `half`, `third`, `quarter`, `fifth` ... `tenth`.

### Places

A place is one of these:

- two numbers: right from the left side, then down from the top: `1/2 3/4`
- a mark: `fly`, `middle`
- a side or corner: `top`, `bottom`, `left`, `right`, `top left`, `bottom right` ...

After a place you can move: `left N`, `right N`, `up N`, `down N`.

```
star 7 points white size 1/7 inner 4/9 at middle right 2/9 up 1/16 up 1/15
```

### More words for each line

- `box`: `from <place> to <place>`, or `size W by H at <place>`; `round N`; `edge <colour> thick N`
- `band`: `across at N thick N`, `down at N thick N`, or `from <place> to <place> thick N shift N left`
- `star`: `N points`, `size N` (outer width), `at <place>`, `inner N` (part of outer), `turn N` (degrees), `edge <colour> thick N`
- `circle`: `size N` (width), `at <place>`, `edge <colour> thick N`
- `shape`: `from <place> to <place> to <place>`, more `to <place>` if you like; `edge <colour> thick N`
- `draw`: `in <part>`. Parts: `all`, `canton`, `top half`, `bottom half`, `left half`, `right half`, `top left quarter` ... `bottom right quarter`, `from <place> to <place>`.
  `hoist` means left, `fly` means right, `upper` means top, `lower` means bottom.
  So `in upper hoist quarter` and `in fly half` work.

## The picture book

`pictures.words` is read first. It has these pictures:

| Picture | Made from |
|---|---|
| `nice boxes` | boxes |
| `union flag` | bands |
| `blue ensign` | paint, `union flag` |
| `southern cross` | stars, placed as Flags Act 1953 Table B says |
| `australian flag` | `blue ensign`, a star, `southern cross` |

A picture can draw other pictures. Each one draws in its own units,
and is made bigger or smaller to fit the part it is drawn in.
So `southern cross` is drawn in a 1 by 1 square, and the fly half of
the flag is that square. The words for each star are the words of the Act.

## Who did what

- Architecture: Tom Dyer
- Code, picture book, README: Claude (Opus 5.5)
- Tested on: Open Object Rexx 5.3.0 r13196
