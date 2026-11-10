#!/usr/bin/env rexx
/* test_glyphs.rex -- read lines in sizes the training did not see, and count the letters that are right
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   Use: rexx test_glyphs.rex [glyphs.txt] */
  parse arg gfile .
  parse source . . me
  home = filespec("location", me)
  if gfile = "" then gfile = home || "glyphs.txt"
  reader = .GlyphReader~new
  reader~load(gfile)
  fonts = .array~of("Liberation Sans", "Liberation Serif", "Liberation Mono", "DejaVu Sans", "DejaVu Serif", "Carlito")
  lines = .array~of("Living Room", "Master Bedroom 2", "Food Pantry/ Porch", "Kitchen & Dining Area", "The quick brown fox jumps over 13 lazy dogs.", "Literally SLAM ooRexx Qzx7 42")
  hintCall = value("WORD_HINT", , "ENVIRONMENT")
  allRightH = 0
  forced = 0
  allRight = 0
  allN = 0
  do size over .array~of(15, 20)
    do font over fonts
      right = 0
      n = 0
      do t over lines
        parse value render(t, font, size) with W H .
        data = .local~ppmData
        wordsIn = reader~readWords(data, W, 0, 0, W - 1, H - 1)
        got = ""
        do wd over wordsIn
          if got \== "" then got = got || " "
          got = got || reader~wordText(wd)
        end
        parse value score(t, got) with r k
        right = right + r
        n = n + k
        /* the same, with the hint call */
        if hintCall \== "" then do
          gotH = withHint(reader, wordsIn, hintCall)
          parse value score(t, gotH) with rH .
          allRightH = allRightH + rH
          /* a word not in the list must not be made into one */
          do w over .array~of("SLAM", "ooRexx", "Qzx7", "42")
            if wordpos(w, t) > 0 then if wordpos(w, got) > 0 then if wordpos(w, gotH) = 0 then forced = forced + 1
          end
          if rH \= r then say "   hint" font size": '"got"' -> '"gotH"'"
        end
        if r < k then say "  " font size": '"t"' -> '"got"'"
      end
      say font size":" right "of" n "letters right"
      allRight = allRight + right
      allN = allN + n
    end
  end
  say "All:" allRight "of" allN "letters right (" || format(100 * allRight / allN, , 1) || "%)"
  if hintCall \== "" then do
    say "With the hint:" allRightH "of" allN "letters right (" || format(100 * allRightH / allN, , 1) || "%)"
    say "Words not in the list that the hint changed:" forced
  end
  exit 0

/* the hint call: an other program, given the near chars of each word */
::routine withHint
  use arg reader, wordsIn, hintCall
  f = "/tmp/hint_" || random(1, 999999)
  s = .stream~new(f".in")
  s~open("write replace")
  do wd over wordsIn
    s~lineout(reader~lattice(wd))
  end
  s~close
  address system hintCall '< "'f'.in"' with output stem ans.
  call SysFileDelete f".in"
  out = ""
  do i = 1 to wordsIn~items
    if out \== "" then out = out || " "
    a = ""
    if i <= ans.0 then a = ans.i
    if word(a, 1) == "HINT" then out = out || word(a, 2)
    else out = out || reader~wordText(wordsIn[i])
  end
  return out

/* letters right, by the same place, spaces not counted */
::routine score
  use arg want, got
  a = want~space(0)
  b = got~space(0)
  r = 0
  do i = 1 to length(a)
    if substr(a, i, 1) == substr(b, i, 1) then r = r + 1
  end
  return r length(a)

::routine render
  use arg text, font, size
  w = trunc(length(text) * size * 0.75 + size * 2)
  h = size * 2
  esc = text~changeStr("&", "&amp;")
  base = "/tmp/tg_" || random(1, 999999)
  s = .stream~new(base".svg")
  s~open("write replace")
  s~lineout('<svg xmlns="http://www.w3.org/2000/svg" width="'w'" height="'h'"><rect width="'w'" height="'h'" fill="white"/>')
  s~lineout('<text x="'size * 0.5 + 0.3'" y="'trunc(size * 1.35) + 0.4'" font-family="'font'" font-size="'size'" fill="black">'esc'</text></svg>')
  s~close
  address system 'rsvg-convert "'base'.svg" -o "'base'.png" && convert "'base'.png" -background white -alpha remove -alpha off ppm:"'base'.ppm"'
  f = base".ppm"
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
  call SysFileDelete base".svg"
  call SysFileDelete base".png"
  call SysFileDelete base".ppm"
  return toks[2] toks[3]

::requires "glyphs.cls"
