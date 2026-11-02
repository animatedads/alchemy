#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* slam_draw.rex  --  SLAM Draw: make a picture from simple words      */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:                                                               */
/*   rexx slam_draw.rex <words file> [out.svg]                        */
/*   rexx slam_draw.rex <sentence; sentence; ...> [out.svg]           */
/*   rexx slam_draw.rex words          (say the words I know)         */
/*                                                                    */
/* The picture book pictures.words (next to this file) is read first. */
/* No word is guessed. A word I do not know stops me, and I say which */
/* word and which line.                                               */
/* ------------------------------------------------------------------ */

  parse arg cmdline
  cmdline = strip(cmdline)
  outFile = "picture.svg"
  if words(cmdline) > 1 then do
    last = word(cmdline, words(cmdline))
    if right(last, 4)~lower = ".svg" then do
      outFile = last
      cmdline = strip(delword(cmdline, words(cmdline)))
    end
  end

  parse source . . me
  home = filespec("location", me)

  signal on syntax name drawError
  drawer = .SlamDraw~new
  drawer~loadFile(home || "pictures.words")

  if cmdline = "" then do
    say "Give me a words file, or sentences split with ;"
    say "Example:  rexx slam_draw.rex draw australian flag flag.svg"
    exit 1
  end
  if cmdline~lower = "words" then do
    drawer~sayWords
    exit 0
  end

  if SysFileExists(cmdline) then drawer~loadFile(cmdline)
  else drawer~loadText(cmdline)

  svgText = drawer~render
  outStream = .stream~new(outFile)
  outStream~open("write replace")
  outStream~charout(svgText)
  outStream~close
  say "I drew" outFile"."
  exit 0

drawError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "SLAM Draw stopped." co["ADDITIONAL"][1]
  else say "SLAM Draw broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  say "  (rc="rc "sigl="sigl "condition="condition("C") "description="condition("D")")"
  exit 2


/* ================================================================== */
::class SlamDraw public
/* ================================================================== */

::constant verbs "size page colour paint box band star circle shape write mark draw make end"
::constant fillers "a an the some please actually"

::method init
  expose book sizes script colours svg clipCount
  book = .directory~new
  sizes = .directory~new
  script = .array~new
  colours = .directory~new
  colours["none"] = "none"
  svg = .array~new
  clipCount = 0

/* ---------------- reading words ----------------------------------- */

::method loadFile
  use arg name
  if \SysFileExists(name) then self~fail(name, 0, "I can not find the file" name".")
  inStream = .stream~new(name)
  lines = inStream~arrayIn
  inStream~close
  self~loadLines(lines, name)

::method loadText
  use arg text
  self~loadLines(text~makeArray(";"), "your words")

::method loadLines
  expose book sizes script
  use arg lines, src
  inWord = ""
  startLine = 0
  do i = 1 to lines~items
    t = self~clean(lines[i])
    if t = "" then iterate
    v = word(t, 1)
    if v = "make" then do
      if inWord <> "" then self~fail(src, i, "I found 'make' before the 'end' of" inWord".")
      inWord = subword(t, 2)
      if inWord = "" then self~fail(src, i, "'make' needs a name.")
      book[inWord] = .array~new
      sizes[inWord] = "1 1"
      startLine = i
      iterate
    end
    if v = "end" then do
      if inWord = "" then self~fail(src, i, "I found 'end' but no 'make'.")
      inWord = ""
      iterate
    end
    if v = "colour" | v = "color" then do
      self~addColour(t, src, i)
      iterate
    end
    entry = .array~of(t, src, i)
    if inWord = "" then script~append(entry)
    else do
      book[inWord]~append(entry)
      if v = "size" then sizes[inWord] = self~parseSize(t, src, i)
    end
  end
  if inWord <> "" then self~fail(src, startLine, "the picture" inWord "has no 'end'.")

::method clean
  use arg line
  /* the words after "saying" are drawn as they are: not small letters, none skipped */
  low = translate(line, " ", "09"x)~lower
  sp = pos(" saying ", low)
  if sp > 0 then do
    tail = strip(substr(translate(line, " ", "09"x), sp + 8))
    return self~clean(left(line, sp - 1)) "saying" tail
  end
  line = translate(line, " ", "09"x)
  p = pos("--", line)
  if p > 0 then line = left(line, p - 1)
  line = space(translate(line, " ", ","))~lower
  if right(line, 1) = "." then line = strip(left(line, length(line) - 1))
  out = ""
  do i = 1 to words(line)
    w = word(line, i)
    if wordpos(w, self~fillers) = 0 then out = out w
  end
  return strip(out)

::method addColour
  expose colours
  use arg t, src, i
  cur = .Cursor~new(t, src, i)
  cur~next
  name = cur~next
  if name = "" then self~fail(src, i, "'colour' needs a name.")
  if toNumber(name) <> "" then self~fail(src, i, "a colour name can not be a number.")
  if cur~peek = "is" then cur~next
  hex = cur~next
  if \self~isHex(hex) then self~fail(src, i, "I need a colour like #ff0000 but I found '"hex"'.")
  if \cur~atEnd then self~fail(src, i, "I did not use these words: '"cur~rest"'.")
  colours[name] = hex

::method isHex
  use arg tok
  if left(tok, 1) <> "#" then return .false
  if wordpos(length(tok), "4 7 9") = 0 then return .false
  return datatype(substr(tok, 2), "X")

::method parseSize
  use arg t, src, i
  cur = .Cursor~new(t, src, i)
  cur~next
  w = self~readNumber(cur, "the width")
  if cur~peek = "by" then cur~next
  h = self~readNumber(cur, "the height")
  if \cur~atEnd then self~fail(src, i, "I did not use these words: '"cur~rest"'.")
  if w <= 0 then self~fail(src, i, "a size must be more than 0.")
  if h <= 0 then self~fail(src, i, "a size must be more than 0.")
  return w h

::method parsePage
  use arg t, src, i
  cur = .Cursor~new(t, src, i)
  cur~next
  n = self~readNumber(cur, "the page")
  k = cur~next
  select
    when k = "by" then return n"|"self~readNumber(cur, "the page height")
    when k = "wide" then return n"|"
    when k = "high" then return "|"n
    otherwise self~fail(src, i, "'page' needs 'by', 'wide' or 'high' after the number.")
  end

/* ---------------- drawing ----------------------------------------- */

::method render
  expose script sizes svg clipCount
  svg = .array~new
  clipCount = 0
  fw = 1
  fh = 1
  found = .false
  pw = ""
  ph = ""
  do entry over script
    v = word(entry[1], 1)
    if v = "size" then do
      parse value self~parseSize(entry[1], entry[2], entry[3]) with fw fh
      found = .true
    end
    if v = "page" then parse value self~parsePage(entry[1], entry[2], entry[3]) with pw "|" ph
  end
  if \found then do
    do entry over script
      if word(entry[1], 1) = "draw" then do
        if wordpos("in", entry[1]) = 0 then do
          nm = subword(entry[1], 2)
          if sizes~hasIndex(nm) then parse value sizes[nm] with fw fh
        end
        leave
      end
    end
  end
  if pw = "" then do
    if ph = "" then ph = 600
    pw = ph * fw / fh
  end
  if ph = "" then ph = pw * fh / fw
  pw = format(pw, , 0)
  ph = format(ph, , 0)

  self~emit('<?xml version="1.0" encoding="UTF-8"?>')
  self~emit('<svg xmlns="http://www.w3.org/2000/svg" width="'pw'" height="'ph'" viewBox="0 0' fmt(fw) fmt(fh)'">')
  self~emit('<!-- drawn by SLAM Draw. Architecture: Tom Dyer. Code: Claude (Opus 5.5). -->')
  self~openFrame(fw, fh)
  self~runEntries(script, fw, fh, 0)
  self~emit('</g>')
  self~emit('</svg>')
  return svg~makeString("L", "0a"x) || "0a"x

::method emit
  expose svg
  use arg text
  svg~append(text)

::method openFrame
  expose clipCount
  use arg w, h
  clipCount = clipCount + 1
  id = "f"clipCount
  self~emit('<clipPath id="'id'"><rect x="0" y="0" width="'fmt(w)'" height="'fmt(h)'"/></clipPath>')
  self~emit('<g clip-path="url(#'id')">')

::method runEntries
  use arg entries, w, h, depth
  marks = .directory~new
  marks["middle"] = w / 2 h / 2
  marks["centre"] = w / 2 h / 2
  marks["center"] = w / 2 h / 2
  do entry over entries
    self~doLine(entry, w, h, marks, depth)
  end

::method doLine
  use arg entry, w, h, marks, depth
  cur = .Cursor~new(entry[1], entry[2], entry[3])
  v = cur~next
  select
    when v = "size" then cur~skipAll
    when v = "page" then cur~skipAll
    when v = "paint" then self~doPaint(cur, w, h)
    when v = "box" then self~doBox(cur, w, h, marks)
    when v = "band" then self~doBand(cur, w, h, marks)
    when v = "star" then self~doStar(cur, w, h, marks)
    when v = "circle" then self~doCircle(cur, w, h, marks)
    when v = "shape" then self~doShape(cur, w, h, marks)
    when v = "write" then self~doWrite(cur, w, h, marks)
    when v = "mark" then self~doMark(cur, w, h, marks)
    when v = "draw" then self~doDraw(cur, w, h, marks, depth)
    otherwise self~fail(cur~src, cur~line, "I do not know the word '"v"'. A line must start with one of:" self~verbs".")
  end
  if \cur~atEnd then self~fail(cur~src, cur~line, "I did not use these words: '"cur~rest"'.")

::method doPaint
  use arg cur, w, h
  if cur~peek = "all" then cur~next
  c = self~readColour(cur)
  self~emit('<rect x="0" y="0" width="'fmt(w)'" height="'fmt(h)'" fill="'c'"/>')

::method doBox
  use arg cur, w, h, marks
  c = self~readColour(cur)
  x0 = ""
  x1 = ""
  cx = ""
  bw = ""
  rnd = 0
  edge = ""
  do while \cur~atEnd
    k = cur~next
    select
      when k = "from" then parse value self~readPoint(cur, marks, w, h) with x0 y0
      when k = "to" then parse value self~readPoint(cur, marks, w, h) with x1 y1
      when k = "at" then parse value self~readPoint(cur, marks, w, h) with cx cy
      when k = "size" then do
        bw = self~readNumber(cur, "the box width")
        if cur~peek = "by" then cur~next
        bh = self~readNumber(cur, "the box height")
      end
      when k = "round" then rnd = self~readNumber(cur, "round")
      when k = "edge" then edge = self~readEdge(cur, h)
      otherwise self~fail(cur~src, cur~line, "in a box I do not know the word '"k"'. I know: from to at size round edge.")
    end
  end
  if bw <> "" then do
    if cx = "" then self~fail(cur~src, cur~line, "a box with 'size' needs 'at'.")
    x0 = cx - bw / 2
    y0 = cy - bh / 2
    x1 = cx + bw / 2
    y1 = cy + bh / 2
  end
  if x0 = "" then self~fail(cur~src, cur~line, "a box needs 'from' and 'to', or 'size' and 'at'.")
  if x1 = "" then self~fail(cur~src, cur~line, "a box needs 'from' and 'to', or 'size' and 'at'.")
  s = '<rect x="'fmt(min(x0, x1))'" y="'fmt(min(y0, y1))'" width="'fmt(abs(x1 - x0))'" height="'fmt(abs(y1 - y0))'"'
  if rnd > 0 then s = s 'rx="'fmt(rnd)'" ry="'fmt(rnd)'"'
  self~emit(s 'fill="'c'"' || edge || '/>')

::method doBand
  use arg cur, w, h, marks
  c = self~readColour(cur)
  mode = cur~next
  if wordpos(mode, "across down from") = 0 then self~fail(cur~src, cur~line, "a band needs 'across', 'down' or 'from' after the colour.")
  if mode = "from" then do
    parse value self~readPoint(cur, marks, w, h) with px py
    self~expect(cur, "to")
    parse value self~readPoint(cur, marks, w, h) with qx qy
  end
  at = ""
  t = ""
  shift = 0
  do while \cur~atEnd
    k = cur~next
    select
      when k = "at" then at = self~readNumber(cur, "at")
      when k = "thick" then t = self~readNumber(cur, "thick")
      when k = "shift" then do
        shift = self~readNumber(cur, "shift")
        side = cur~next
        if wordpos(side, "left right") = 0 then self~fail(cur~src, cur~line, "'shift' needs 'left' or 'right' after the number.")
        if side = "right" then shift = -shift
      end
      otherwise self~fail(cur~src, cur~line, "in a band I do not know the word '"k"'. I know: at thick shift.")
    end
  end
  if t = "" then self~fail(cur~src, cur~line, "a band needs 'thick'.")
  if mode = "across" then do
    if at = "" then self~fail(cur~src, cur~line, "a band across needs 'at'.")
    self~emit('<rect x="0" y="'fmt(at - t / 2)'" width="'fmt(w)'" height="'fmt(t)'" fill="'c'"/>')
    return
  end
  if mode = "down" then do
    if at = "" then self~fail(cur~src, cur~line, "a band down needs 'at'.")
    self~emit('<rect x="'fmt(at - t / 2)'" y="0" width="'fmt(t)'" height="'fmt(h)'" fill="'c'"/>')
    return
  end
  dx = qx - px
  dy = qy - py
  len = RxCalcSqrt(dx * dx + dy * dy, 12)
  if len = 0 then self~fail(cur~src, cur~line, "a band needs two different places.")
  /* left of the way you go, on a page where down is +y */
  lx = dy / len
  ly = -dx / len
  a = shift + t / 2
  b = shift - t / 2
  pts = fmt(px + lx * a)","fmt(py + ly * a) fmt(qx + lx * a)","fmt(qy + ly * a)
  pts = pts fmt(qx + lx * b)","fmt(qy + ly * b) fmt(px + lx * b)","fmt(py + ly * b)
  self~emit('<polygon points="'pts'" fill="'c'"/>')

::method doStar
  use arg cur, w, h, marks
  n = 5
  num = toNumber(cur~peek)
  if num <> "" then do
    cur~next
    n = num
    if wordpos(cur~peek, "points point") > 0 then cur~next
  end
  if \datatype(n, "W") then self~fail(cur~src, cur~line, "a star needs a whole number of points.")
  if n < 3 then self~fail(cur~src, cur~line, "a star needs 3 points or more.")
  c = self~readColour(cur)
  d = ""
  cx = ""
  inner = 1 / 2
  turn = 0
  edge = ""
  do while \cur~atEnd
    k = cur~next
    select
      when k = "size" then d = self~readNumber(cur, "the star size")
      when k = "at" then parse value self~readPoint(cur, marks, w, h) with cx cy
      when k = "inner" then inner = self~readNumber(cur, "inner")
      when k = "turn" then turn = self~readNumber(cur, "turn")
      when k = "edge" then edge = self~readEdge(cur, h)
      otherwise self~fail(cur~src, cur~line, "in a star I do not know the word '"k"'. I know: size at inner turn edge.")
    end
  end
  if d = "" then self~fail(cur~src, cur~line, "a star needs 'size'.")
  if cx = "" then self~fail(cur~src, cur~line, "a star needs 'at'.")
  big = d / 2
  small = big * inner
  pts = ""
  do k = 0 to 2 * n - 1
    ang = -90 + turn + k * 180 / n
    if k // 2 = 0 then r = big
    else r = small
    pts = pts fmt(cx + r * RxCalcCos(ang, 12))","fmt(cy + r * RxCalcSin(ang, 12))
  end
  self~emit('<polygon points="'strip(pts)'" fill="'c'"' || edge || '/>')

::method doCircle
  use arg cur, w, h, marks
  c = self~readColour(cur)
  d = ""
  cx = ""
  edge = ""
  do while \cur~atEnd
    k = cur~next
    select
      when k = "size" then d = self~readNumber(cur, "the circle size")
      when k = "at" then parse value self~readPoint(cur, marks, w, h) with cx cy
      when k = "edge" then edge = self~readEdge(cur, h)
      otherwise self~fail(cur~src, cur~line, "in a circle I do not know the word '"k"'. I know: size at edge.")
    end
  end
  if d = "" then self~fail(cur~src, cur~line, "a circle needs 'size'.")
  if cx = "" then self~fail(cur~src, cur~line, "a circle needs 'at'.")
  self~emit('<circle cx="'fmt(cx)'" cy="'fmt(cy)'" r="'fmt(d / 2)'" fill="'c'"' || edge || '/>')

/* shape <colour> from <place> to <place> to <place> ... [edge ...]   */
/* added for the South Africa flag: a shape with straight sides       */
::method doShape
  use arg cur, w, h, marks
  c = self~readColour(cur)
  self~expect(cur, "from")
  parse value self~readPoint(cur, marks, w, h) with x y
  pts = fmt(x)","fmt(y)
  count = 1
  edge = ""
  do while \cur~atEnd
    k = cur~next
    select
      when k = "to" then do
        parse value self~readPoint(cur, marks, w, h) with x y
        pts = pts fmt(x)","fmt(y)
        count = count + 1
      end
      when k = "edge" then edge = self~readEdge(cur, h)
      otherwise self~fail(cur~src, cur~line, "in a shape I do not know the word '"k"'. I know: from to edge.")
    end
  end
  if count < 3 then self~fail(cur~src, cur~line, "a shape needs 3 places or more: from <place> to <place> to <place>.")
  self~emit('<polygon points="'pts'" fill="'c'"' || edge || '/>')

/* write <colour> size <n> at <place> saying <words to the end>       */
/* added for plans: the words are drawn with their middle at the place */
::method doWrite
  use arg cur, w, h, marks
  c = self~readColour(cur)
  s = h / 20
  cx = ""
  text = ""
  turn = 0
  do while \cur~atEnd
    k = cur~next
    select
      when k = "size" then s = self~readNumber(cur, "the size of the words")
      when k = "at" then parse value self~readPoint(cur, marks, w, h) with cx cy
      when k = "turn" then turn = self~readNumber(cur, "turn")
      when k = "saying" then do
        text = cur~rest
        cur~skipAll
      end
      otherwise self~fail(cur~src, cur~line, "in write I do not know the word '"k"'. I know: size at turn saying.")
    end
  end
  if cx = "" then self~fail(cur~src, cur~line, "write needs 'at'.")
  if text = "" then self~fail(cur~src, cur~line, "write needs 'saying' and the words to write.")
  text = text~changeStr("&", "&amp;")~changeStr("<", "&lt;")~changeStr(">", "&gt;")
  rot = ""
  if turn \= 0 then rot = ' transform="rotate('fmt(turn) fmt(cx) fmt(cy)')"'
  self~emit('<text x="'fmt(cx)'" y="'fmt(cy)'" font-size="'fmt(s)'" font-family="sans-serif" text-anchor="middle" dominant-baseline="central" fill="'c'"' || rot || '>'text'</text>')

::method doMark
  use arg cur, w, h, marks
  name = cur~next
  if name = "" then self~fail(cur~src, cur~line, "'mark' needs a name.")
  if toNumber(name) <> "" then self~fail(cur~src, cur~line, "a mark name can not be a number.")
  if wordpos(name, "top bottom left right up down at") > 0 then self~fail(cur~src, cur~line, "'"name"' is a place word. Give the mark another name.")
  self~expect(cur, "at")
  marks[name] = self~readPoint(cur, marks, w, h)

::method doDraw
  expose book sizes
  use arg cur, w, h, marks, depth
  name = ""
  do while \cur~atEnd
    if cur~peek = "in" then leave
    name = name cur~next
  end
  name = strip(name)
  if \book~hasIndex(name) then self~fail(cur~src, cur~line, "I have no picture called '"name"'. I have:" self~pictureNames".")
  rx0 = 0
  ry0 = 0
  rx1 = w
  ry1 = h
  if cur~peek = "in" then do
    cur~next
    parse value self~readRegion(cur, marks, w, h) with rx0 ry0 rx1 ry1
  end
  if depth >= 12 then self~fail(cur~src, cur~line, "the picture '"name"' goes too deep. Does it draw itself?")
  parse value sizes[name] with ww wh
  sx = (rx1 - rx0) / ww
  sy = (ry1 - ry0) / wh
  self~emit('<!-- picture:' name '-->')
  self~emit('<g transform="translate('fmt(rx0) fmt(ry0)') scale('fmt(sx) fmt(sy)')">')
  self~openFrame(ww, wh)
  self~runEntries(book[name], ww, wh, depth + 1)
  self~emit('</g>')
  self~emit('</g>')

/* ---------------- small readers ----------------------------------- */

::method readColour
  expose colours
  use arg cur
  tok = cur~next
  if colours~hasIndex(tok) then return colours[tok]
  if self~isHex(tok) then return tok
  self~fail(cur~src, cur~line, "I do not know the colour '"tok"'. I know:" self~colourNames".")

::method readEdge
  use arg cur, h
  c = self~readColour(cur)
  t = h / 100
  if cur~peek = "thick" then do
    cur~next
    t = self~readNumber(cur, "the edge thick")
  end
  return ' stroke="'c'" stroke-width="'fmt(t)'" stroke-linejoin="round"'

::method readNumber
  use arg cur, what
  tok = cur~next
  n = toNumber(tok)
  if n <> "" then return n
  if tok = "" then self~fail(cur~src, cur~line, "I need a number for" what "but the line stopped.")
  self~fail(cur~src, cur~line, "I need a number for" what "but I found '"tok"'.")

::method expect
  use arg cur, want
  tok = cur~next
  if tok <> want then self~fail(cur~src, cur~line, "I need the word '"want"' here but I found '"tok"'.")

::method readPoint
  use arg cur, marks, w, h
  tok = cur~peek
  n = toNumber(tok)
  select
    when n <> "" then do
      cur~next
      x = n
      y = self~readNumber(cur, "the down place")
    end
    when marks~hasIndex(tok) then do
      cur~next
      parse value marks[tok] with x y
    end
    when tok = "top" | tok = "bottom" then do
      cur~next
      x = w / 2
      if tok = "top" then y = 0
      else y = h
      side = cur~peek
      if side = "left" | side = "right" then do
        if toNumber(cur~peek(1)) = "" then do
          cur~next
          if side = "left" then x = 0
          else x = w
        end
      end
    end
    when tok = "left" | tok = "right" then do
      if toNumber(cur~peek(1)) <> "" then self~fail(cur~src, cur~line, "a place can not start with a move. Start with a number, a mark, top, bottom, left or right.")
      cur~next
      y = h / 2
      if tok = "left" then x = 0
      else x = w
    end
    otherwise
      if tok = "" then self~fail(cur~src, cur~line, "I need a place but the line stopped.")
      self~fail(cur~src, cur~line, "I need a place but I found '"tok"'. A place is two numbers, a mark, top, bottom, left, right or middle.")
  end
  do forever
    d = cur~peek
    if wordpos(d, "left right up down") = 0 then leave
    m = toNumber(cur~peek(1))
    if m = "" then leave
    cur~next
    cur~next
    select
      when d = "left" then x = x - m
      when d = "right" then x = x + m
      when d = "up" then y = y - m
      otherwise y = y + m
    end
  end
  return x y

::method readRegion
  use arg cur, marks, w, h
  if cur~peek = "from" then do
    cur~next
    parse value self~readPoint(cur, marks, w, h) with x0 y0
    self~expect(cur, "to")
    parse value self~readPoint(cur, marks, w, h) with x1 y1
    return min(x0, x1) min(y0, y1) max(x0, x1) max(y0, y1)
  end
  phrase = ""
  do while \cur~atEnd
    tok = cur~next
    i = wordpos(tok, "upper lower hoist fly")
    if i > 0 then tok = word("top bottom left right", i)
    phrase = phrase tok
  end
  phrase = strip(phrase)
  select
    when phrase = "all" then f = "0 0 1 1"
    when phrase = "canton" then f = "0 0 0.5 0.5"
    when phrase = "top half" then f = "0 0 1 0.5"
    when phrase = "bottom half" then f = "0 0.5 1 1"
    when phrase = "left half" then f = "0 0 0.5 1"
    when phrase = "right half" then f = "0.5 0 1 1"
    when phrase = "top left quarter" then f = "0 0 0.5 0.5"
    when phrase = "top right quarter" then f = "0.5 0 1 0.5"
    when phrase = "bottom left quarter" then f = "0 0.5 0.5 1"
    when phrase = "bottom right quarter" then f = "0.5 0.5 1 1"
    otherwise self~fail(cur~src, cur~line, "I do not know the place '"phrase"'. I know: all, canton, top half, bottom half, left half, right half, top left quarter, top right quarter, bottom left quarter, bottom right quarter, from <place> to <place>. Hoist means left, fly means right, upper means top, lower means bottom.")
  end
  parse var f a b c d
  return a * w b * h c * w d * h

/* ---------------- telling ----------------------------------------- */

::method pictureNames
  expose book
  return book~allIndexes~sort~makeString("L", ", ")

::method colourNames
  expose colours
  return colours~allIndexes~sort~makeString("L", ", ")

::method sayWords
  say "Line words :" self~verbs
  say "Pictures   :" self~pictureNames
  say "Colours    :" self~colourNames
  say "Numbers    : 2  0.5  3/10  half third quarter fifth sixth seventh eighth ninth tenth"
  say "Places     : two numbers, a mark, middle, top, bottom, left, right, top left ..."
  say "Moves      : left N  right N  up N  down N  (after a place)"
  say "Skipped    :" self~fillers

::method fail
  use arg src, line, msg
  where = ""
  if line > 0 then where = src "line" line": "
  /* syntax conditions travel up to the caller; user conditions do not */
  raise syntax 98.900 array (where || msg)


/* ================================================================== */
::class Cursor
/* ================================================================== */
::attribute src get
::attribute line get

::method init
  expose toks pos src line
  use arg text, src, line
  toks = text~makeArray(" ")
  pos = 1

::method peek
  expose toks pos
  use arg ahead = 0
  k = pos + ahead
  if k > toks~items then return ""
  return toks[k]

::method next
  expose toks pos
  if pos > toks~items then return ""
  tok = toks[pos]
  pos = pos + 1
  return tok

::method atEnd
  expose toks pos
  return pos > toks~items

::method skipAll
  expose toks pos
  pos = toks~items + 1

::method rest
  expose toks pos
  out = ""
  do k = pos to toks~items
    out = out toks[k]
  end
  return strip(out)


/* ================================================================== */
::routine toNumber
  use arg tok
  p = wordpos(tok, "half third quarter fifth sixth seventh eighth ninth tenth")
  if p > 0 then return 1 / word("2 3 4 5 6 7 8 9 10", p)
  if pos("/", tok) > 0 then do
    parse var tok a "/" b
    if datatype(a, "N") then do
      if datatype(b, "N") then do
        if b <> 0 then return a / b
      end
    end
    return ""
  end
  if datatype(tok, "N") then return tok
  return ""

::routine fmt
  use arg n
  s = format(n, , 6)
  if pos(".", s) > 0 then s = strip(strip(s, "T", "0"), "T", ".")
  if s = "-0" then s = "0"
  return s

::requires "rxmath" LIBRARY
