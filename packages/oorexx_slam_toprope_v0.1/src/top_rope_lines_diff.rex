/* ------------------------------------------------------------------ */
/* top_rope_lines_diff.rex -- the street lines alone: a lined aerial   */
/*   less its plain twin                                              */
/*                                                                    */
/* Architecture : Tom Dyer (lay one picture on the other, low first,  */
/*                then detail; V5V dual mode)                         */
/* Code         : Claude (Opus 5.5)                                   */
/* Pictures     : NSW Government aerials (CC BY 4.0)                  */
/*                                                                    */
/* rexx top_rope_lines_diff.rex lined.png plain.png lines.pgm [check] */
/*                                                                    */
/* The viewer shows the same photo with and without street lines, at  */
/* the same zoom (1:5,505) but framed differently. So:                */
/*  1 each picture as kinds, from the stitch tools: here the kind is  */
/*    dark (shadows, street canyons, water) or light, split at the     */
/*    picture's own middle grey;                                       */
/*  2 lay the lined picture on the plain one with the stitch's search */
/*    (big cells first, then detail near the best), at zoom 1: kappa  */
/*    says how well dark meets dark;                                  */
/*  3 where both see the place, a line place is one the lined picture */
/*    shows at least LIFT brighter than the plain one, and grey.      */
/*    The street names' black writing is darker, so it drops out; its */
/*    white band is brighter, so it stays with its street.            */
/* ------------------------------------------------------------------ */
parse arg linedPic plainPic out check .
if out = "" then do
  say "usage: rexx top_rope_lines_diff.rex lined.png plain.png lines.pgm [check.png]"
  exit 2
end
LIFT = 40; GREYNESS = 40; F = 2
/* the least share of the picture that must overlap; LAY_OVERLAP sets it */
minOv = value("LAY_OVERLAP", , "ENVIRONMENT"); if \datatype(minOv, "N") then minOv = 0.25
L = .Master~new(linedPic); P = .Master~new(plainPic)
lp = kindsOf(L, F); pp = kindsOf(P, F)
say "lined" L~W "x" L~H", plain" P~W "x" P~H "(cells of" F")"

/* 2: low first: cells of 8, the whole range of places */
L8 = levelOf(lp, 8); P8 = levelOf(pp, 8)
top = search(P8, L8, 1 - length(L8[1]), length(P8[1]) - 1, 1 - L8~items, P8~items - 1, minOv)
if top~items = 0 then raise syntax 88.900 array("no lay found")
parse value top[1] with k8 tx8 ty8 ov8
say "low (cells of 8): kappa" k8 "at" tx8 ty8 "overlap" ov8
/* then detail: cells of 4, then single cells, near the low answer   */
L4 = levelOf(lp, 4); P4 = levelOf(pp, 4)
r4 = fitAt(P4, L4, 1, tx8 * 2, ty8 * 2, 0.01, 0, 3, minOv)
parse var r4 k4 . tx4 ty4 ov4
L1 = levelOf(lp, 1); P1 = levelOf(pp, 1)
r1 = fitAt(P1, L1, 1, tx4 * 4, ty4 * 4, 0.01, 0, 5, minOv)
parse var r1 k1 . tx1 ty1 ov1
dx = tx1 * F; dy = ty1 * F
say "detail: kappa" k1 "; the lined picture's place (0, 0) is the plain picture's (" dx"," dy")"

/* 3: lines where the lined picture is brighter than the plain one */
lw = L~W; lh = L~H; pw = P~W; ph = P~H
lr = L~rgb; pr = P~rgb
mask = .mutableBuffer~new(, lw * lh)
nLine = 0; nSeen = 0
do y = 0 to lh - 1
  py = y + dy
  do x = 0 to lw - 1
    px = x + dx
    if px < 0 | py < 0 | px >= pw | py >= ph then do; mask~append("00"x); iterate; end
    nSeen += 1
    i = 3 * (y * lw + x); j = 3 * (py * pw + px)
    r = c2d(substr(lr, i + 1, 1)); g = c2d(substr(lr, i + 2, 1)); b = c2d(substr(lr, i + 3, 1))
    v = (r + g + b) / 3
    w = (c2d(substr(pr, j + 1, 1)) + c2d(substr(pr, j + 2, 1)) + c2d(substr(pr, j + 3, 1))) / 3
    if v - w >= LIFT & max(r, g, b) - min(r, g, b) <= GREYNESS then do
      mask~append("ff"x); nLine += 1
    end
    else mask~append("00"x)
  end
end
say "line places:" nLine "of" nSeen "seen by both"
/* a line is a joined run of LONG places or more (8 ways); specks from  */
/* wave glitter or render noise between the two pictures drop out     */
LONG = 30
ms = mask~string
keep = .mutableBuffer~new(copies("00"x, lw * lh))
seen = .mutableBuffer~new(copies("0", lw * lh))
p = 0; nKept = 0; nDrop = 0
do forever
  p = pos("ff"x, ms, p + 1)
  if p = 0 then leave
  if substr(seen, p, 1) == "1" then iterate
  comp = .array~new; q = .queue~new; q~queue(p); seen~replaceAt("1", p, 1)
  do while q~items > 0
    j = q~pull; comp~append(j)
    jx = (j - 1) // lw
    do d over .array~of(-1, 1, -lw, lw, -lw - 1, -lw + 1, lw - 1, lw + 1)
      kk = j + d
      if kk < 1 | kk > lw * lh then iterate
      if abs((kk - 1) // lw - jx) > 1 then iterate
      if substr(ms, kk, 1) \== "ff"x | substr(seen, kk, 1) == "1" then iterate
      seen~replaceAt("1", kk, 1); q~queue(kk)
    end
  end
  if comp~items >= LONG then do
    do j over comp; keep~replaceAt("ff"x, j, 1); end
    nKept += comp~items
  end
  else nDrop += comp~items
end
mask = keep
say "kept" nKept "line places in runs of" LONG "or more; dropped" nDrop "in specks"
call SysFileDelete out
call charout out, "P5" || "0a"x || lw lh || "0a"x || "255" || "0a"x || mask~string
call stream out, "c", "close"
say "wrote" out
call lineout out".words", "lined" filespec("name", linedPic) "on plain" filespec("name", plainPic) "at" dx dy "kappa" k1
call stream out".words", "c", "close"
if check \== "" then do
  address system 'convert "' || linedPic || '" -modulate 55 \( "' || out || '" -fill "#ff2a2a" -opaque white -transparent black \) -composite "' || check || '"'
  say "wrote" check
end
exit 0

/* the kinds of a picture: dark ("w") or light ("l") in cells of f,   */
/* split at its own middle grey; shaped like readPicture's answer so  */
/* the stitch's levelOf, search and fitAt can use it                  */
::routine kindsOf
  use arg m, f
  WW = m~W % f; HH = m~H % f; rgb = m~rgb; FW = m~W
  tally = .array~new(256)
  do i = 0 to 255; tally[i + 1] = 0; end
  do p = 1 to length(rgb) by 3 * 11
    v = (c2d(substr(rgb, p, 1)) + c2d(substr(rgb, p + 1, 1)) + c2d(substr(rgb, p + 2, 1))) % 3
    tally[v + 1] += 1
  end
  half = 0; do i = 1 to 256; half += tally[i]; end; half = half / 2
  run = 0; mid = 128
  do i = 1 to 256
    run += tally[i]
    if run >= half then do; mid = i - 1; leave; end
  end
  kinds = .array~new(WW * HH)
  n = 0
  do y = 0 to HH - 1
    do x = 0 to WW - 1
      s = 0
      do dy = 0 to f - 1
        do dx = 0 to f - 1
          p = ((y * f + dy) * FW + x * f + dx) * 3 + 1
          s += c2d(substr(rgb, p, 1)) + c2d(substr(rgb, p + 1, 1)) + c2d(substr(rgb, p + 2, 1))
        end
      end
      n += 1
      if s / (3 * f * f) < mid then kinds[n] = "w"; else kinds[n] = "l"
    end
  end
  pc = .directory~new
  pc~W = WW; pc~H = HH; pc~kinds = kinds
  return pc

::requires "stitch.cls"
::requires "master.cls"
