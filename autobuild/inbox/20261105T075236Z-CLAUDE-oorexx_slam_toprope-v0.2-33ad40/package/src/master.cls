/* ------------------------------------------------------------------ */
/* master.cls -- the picture, held in memory one time                 */
/*                                                                    */
/* Architecture : Tom Dyer (one master in memory; grey when it can be */
/*                grey, colour only when it is needed)                */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* One call to ImageMagick reads the picture (any kind) as RGB. All   */
/* else is done here, from that one copy:                            */
/*   grey    the grey of each place (made one time, kept)             */
/*   isGrey  the picture has no colour that is needed                 */
/*   shrink  a smaller copy (each place the mean of the places in it) */
/*   square  a square of the master, turned by an angle               */
/* ------------------------------------------------------------------ */

::class Master public
::attribute W get
::attribute H get
::attribute rgb get

::method init
  expose W H rgb greyData greyKnown
  use arg picture
  greyData = .nil
  greyKnown = .nil
  f = "/tmp/master_" || random(1, 999999) || ".ppm"
  address system 'convert "'picture'" -background white -alpha remove -alpha off ppm:"'f'"'
  if \SysFileExists(f) then raise syntax 98.900 array ("ImageMagick could not read" picture".")
  s = .stream~new(f)
  s~open("read")
  data = s~charin(1, s~chars)
  s~close
  call SysFileDelete f
  toks = .array~new
  p = 1
  do while toks~items < 4
    ch = substr(data, p, 1)
    if ch = "#" then do
      p = pos("0a"x, data, p) + 1
      iterate
    end
    if verify(ch, "200a0d09"x) = 0 then do
      p = p + 1
      iterate
    end
    q = verify(data, "200a0d09"x, "M", p)
    toks~append(substr(data, p, q - p))
    p = q
  end
  W = toks[2]
  H = toks[3]
  rgb = substr(data, p + 1, W * H * 3)

/* the grey of each place, one byte each: made one time */
::method grey
  expose W H rgb greyData
  if greyData \== .nil then return greyData
  mb = .mutableBuffer~new(, W * H)
  cache = .directory~new
  do p = 1 to W * H * 3 by 3
    k = substr(rgb, p, 3)
    v = cache[k]
    if v == .nil then do
      v = d2c(trunc(0.299 * c2d(substr(k, 1, 1)) + 0.587 * c2d(substr(k, 2, 1)) + 0.114 * c2d(substr(k, 3, 1)) + 0.5))
      cache[k] = v
    end
    mb~append(v)
  end
  greyData = mb~string
  return greyData

/* no colour is needed when (almost) each place is grey: red, green and blue the same, near */
::method isGrey
  expose W H rgb greyKnown
  if greyKnown \== .nil then return greyKnown
  n = 0
  off = 0
  step = max(1, trunc(W * H / 20000))
  do i = 0 to W * H - 1 by step
    p = i * 3 + 1
    r = c2d(substr(rgb, p, 1))
    g = c2d(substr(rgb, p + 1, 1))
    b = c2d(substr(rgb, p + 2, 1))
    n = n + 1
    if max(r, g, b) - min(r, g, b) > 12 then off = off + 1
  end
  greyKnown = (off <= 0.005 * n)
  return greyKnown

/* a smaller copy, nw by nh; bpp 1 (grey) or 3 (colour); each place the mean of the master places in it */
::method shrink
  expose W H rgb
  use arg nw, nh, bpp
  if bpp = 1 then src = self~grey
  else src = rgb
  if nw = W then if nh = H then return src
  sx = W / nw
  sy = H / nh
  /* the numbers of each colour, one time (a picture has few colours, many times) */
  num = .directory~new
  mb = .mutableBuffer~new(, nw * nh * bpp)
  do y = 0 to nh - 1
    ya = trunc(y * sy)
    yb = max(ya, trunc((y + 1) * sy) - 1)
    do x = 0 to nw - 1
      xa = trunc(x * sx)
      xb = max(xa, trunc((x + 1) * sx) - 1)
      s1 = 0
      s2 = 0
      s3 = 0
      n = 0
      do yy = ya to yb
        base = yy * W
        do xx = xa to xb
          k = substr(src, (base + xx) * bpp + 1, bpp)
          v = num[k]
          if v == .nil then do
            if bpp = 1 then v = c2d(k)
            else v = c2d(substr(k, 1, 1)) c2d(substr(k, 2, 1)) c2d(substr(k, 3, 1))
            num[k] = v
          end
          if bpp = 1 then s1 = s1 + v
          else do
            parse var v r g b
            s1 = s1 + r
            s2 = s2 + g
            s3 = s3 + b
          end
          n = n + 1
        end
      end
      if bpp = 1 then mb~append(d2c(trunc(s1 / n + 0.5)))
      else mb~append(d2c(trunc(s1 / n + 0.5)) || d2c(trunc(s2 / n + 0.5)) || d2c(trunc(s3 / n + 0.5)))
    end
  end
  return mb~string

/* a square of the master (grey), turned by a degrees (as ImageMagick -rotate: with the clock).
   Returns "w h" and puts the data in .local~squareData. 0, 90, 180, 270: places are only moved.
   Other angles: each place is from the four master places round it. Outside the master: white. */
::method square
  expose W H
  use arg x0, y0, x1, y1, a
  g = self~grey
  sw = x1 - x0 + 1
  sh = y1 - y0 + 1
  a = (a // 360 + 360) // 360
  mb = .mutableBuffer~new
  select
    when a = 0 then do
      do y = y0 to y1
        mb~append(substr(g, y * W + x0 + 1, sw))
      end
      .local~squareData = mb~string
      return sw sh
    end
    when a = 90 then do
      /* turned with the clock: the new first row is the old first column, from the bottom */
      do x = x0 to x1
        do y = y1 to y0 by -1
          mb~append(substr(g, y * W + x + 1, 1))
        end
      end
      .local~squareData = mb~string
      return sh sw
    end
    when a = 180 then do
      do y = y1 to y0 by -1
        mb~append(reverse(substr(g, y * W + x0 + 1, sw)))
      end
      .local~squareData = mb~string
      return sw sh
    end
    when a = 270 then do
      do x = x1 to x0 by -1
        do y = y0 to y1
          mb~append(substr(g, y * W + x + 1, 1))
        end
      end
      .local~squareData = mb~string
      return sh sw
    end
    otherwise nop
  end
  cs = RxCalcCos(a, 9)
  sn = RxCalcSin(a, 9)
  nw = trunc(abs(sw * cs) + abs(sh * sn) + 0.5)
  nh = trunc(abs(sw * sn) + abs(sh * cs) + 0.5)
  cx = x0 + sw / 2
  cy = y0 + sh / 2
  do v = 0 to nh - 1
    dy = v + 0.5 - nh / 2
    do u = 0 to nw - 1
      dx = u + 0.5 - nw / 2
      /* the place in the master: turned back */
      fx = cx + dx * cs + dy * sn - 0.5
      fy = cy - dx * sn + dy * cs - 0.5
      ix = trunc(fx)
      iy = trunc(fy)
      if fx < 0 | fy < 0 | ix >= W - 1 | iy >= H - 1 then do
        mb~append("FF"x)
        iterate
      end
      tx = fx - ix
      ty = fy - iy
      p = iy * W + ix + 1
      v00 = c2d(substr(g, p, 1))
      v10 = c2d(substr(g, p + 1, 1))
      v01 = c2d(substr(g, p + W, 1))
      v11 = c2d(substr(g, p + W + 1, 1))
      top = v00 + (v10 - v00) * tx
      bot = v01 + (v11 - v01) * tx
      mb~append(d2c(trunc(top + (bot - top) * ty + 0.5)))
    end
  end
  .local~squareData = mb~string
  return nw nh

::requires "rxmath" LIBRARY
