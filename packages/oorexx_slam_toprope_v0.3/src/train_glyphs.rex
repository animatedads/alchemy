#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* train_glyphs.rex -- learn letters in 6 fonts, for Top Rope Slam    */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:  rexx train_glyphs.rex [glyphs.txt]                           */
/*                                                                    */
/* For each font and size: one sheet (SVG, drawn by rsvg-convert).    */
/* In each cell: an H (it gives the line and the height of a capital) */
/* and one char. The char is seen with the same steps as when I read  */
/* (glyphs.cls), and its numbers go in glyphs.txt.                    */
/* Needs rsvg-convert and ImageMagick convert, and the 6 fonts.       */
/* Upright only: no turn and no slope are learned (not yet).          */
/* ------------------------------------------------------------------ */
  parse arg outFile .
  parse source . . me
  home = filespec("location", me)
  if outFile = "" then outFile = home || "glyphs.txt"
  fonts = .array~of("Liberation Sans", "Liberation Serif", "Liberation Mono", "DejaVu Sans", "DejaVu Serif", "Carlito")
  sizes = .array~of(13, 17, 23)
  chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,:;-/()&'?!%+"
  reader = .GlyphReader~new
  cols = 10
  do font over fonts
    do size over sizes
      cw = size * 3
      chh = size * 2
      rows = (length(chars) + cols - 1) % cols
      pw = cw * cols
      ph = chh * rows
      svg = .array~new
      svg~append('<svg xmlns="http://www.w3.org/2000/svg" width="'pw'" height="'ph'" viewBox="0 0' pw ph'">')
      svg~append('<rect x="0" y="0" width="'pw'" height="'ph'" fill="white"/>')
      do i = 1 to length(chars)
        ch = substr(chars, i, 1)
        cx = ((i - 1) // cols) * cw
        cy = ((i - 1) % cols) * chh
        by = cy + trunc(size * 1.35)
        svg~append('<text x="'cx + size * 0.2'" y="'by'" font-family="'font'" font-size="'size'" fill="black">H</text>')
        svg~append('<text x="'cx + size * 1.4'" y="'by'" font-family="'font'" font-size="'size'" fill="black">'xmlText(ch)'</text>')
      end
      svg~append('</svg>')
      base = "/tmp/train_" || random(1, 999999)
      s = .stream~new(base".svg")
      s~open("write replace")
      do line over svg
        s~lineout(line)
      end
      s~close
      address system 'rsvg-convert "'base'.svg" -o "'base'.png" && convert "'base'.png" -background white -alpha remove -alpha off ppm:"'base'.ppm"'
      parse value readPpm(base".ppm") with W H .
      data = .local~ppmData
      call SysFileDelete base".svg"
      call SysFileDelete base".png"
      call SysFileDelete base".ppm"
      got = 0
      do i = 1 to length(chars)
        ch = substr(chars, i, 1)
        cx = ((i - 1) // cols) * cw
        cy = ((i - 1) % cols) * chh
        r = reader~glyphsIn(data, W, cx, cy, cx + cw - 1, cy + chh - 1)
        gl = r["GLYPHS"]
        if gl~items < 2 then iterate
        /* the H is the first glyph; all after it is the char */
        parse value gl[1] with a0 b0 a1 b1
        base0 = b1
        cap = b1 - b0 + 1
        u0 = 1e9
        v0 = 1e9
        u1 = -1
        v1 = -1
        do k = 2 to gl~items
          parse value gl[k] with p0 q0 p1 q1
          u0 = min(u0, p0)
          v0 = min(v0, q0)
          u1 = max(u1, p1)
          v1 = max(v1, q1)
        end
        f = reader~features(r["COV"], r["RW"], u0 v0 u1 v1, base0, cap)
        f["CH"] = ch
        f["FONT"] = font~changeStr(" ", "_")
        f["SIZE"] = size
        reader~add(f)
        got = got + 1
      end
      say font size":" got "of" length(chars) "chars learned"
    end
  end
  reader~save(outFile)
  say "I learned" reader~count "glyphs. They are in" outFile"."
  exit 0

::routine xmlText
  use arg ch
  if ch == "&" then return "&amp;"
  if ch == "<" then return "&lt;"
  if ch == ">" then return "&gt;"
  if ch == "'" then return "&apos;"
  return ch

::routine readPpm
  use arg f
  s = .stream~new(f)
  s~open("read")
  data = s~charin(1, s~chars)
  s~close
  toks = .array~new
  p = 1
  do while toks~items < 4
    ch = substr(data, p, 1)
    if verify(ch, "200a0d09"x) = 0 then do
      p = p + 1
      iterate
    end
    q = verify(data, "200a0d09"x, "M", p)
    toks~append(substr(data, p, q - p))
    p = q
  end
  .local~ppmData = substr(data, p + 1)
  return toks[2] toks[3]

::requires "glyphs.cls"
