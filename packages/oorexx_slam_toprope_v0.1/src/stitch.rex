#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* stitch.rex -- SLAM stitches pictures of the same place together     */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use: rexx stitch.rex <words out> [bottom <rows>] <picture> ...     */
/*   bottom <rows>  rows at the bottom of each picture that are screen*/
/*                  furniture, not the earth (Google: 16)             */
/* TOPROPE_DEBUG=stitch shows the work; =time shows how long          */
/*                                                                    */
/* How SLAM stitches (stitch_words.md says it in SLAM words):         */
/*   1 each picture: water and land; specks take the kind round them */
/*   2 each picture: its islands, each with a shape print that does   */
/*     not change with zoom                                           */
/*   3 each two pictures: islands that look alike give guesses (zoom, */
/*     place); the guess most islands agree on is checked first       */
/*   4 a guess is checked by laying one picture on the other: kappa   */
/*     says how much better than chance water meets water             */
/*   5 a picture with no island fit: search, low resolution first,    */
/*     trying the zooms SLAM has seen before first (lessons)          */
/*   6 keep the strongest fits that join all pictures (a tree); the   */
/*     widest picture is the frame for the rest                       */
/*   7 write where each picture goes, in SLAM words; learn the zooms  */
/* ------------------------------------------------------------------ */
  parse arg outWords rest
  if outWords = "" | rest = "" then do
    say "Use: rexx stitch.rex <words out> [bottom <rows>] <picture> <picture> ..."
    exit 1
  end
  signal on syntax name seeError
  call time "R"
  parse source . . me
  home = filespec("location", me)
  dbg = pos("stitch", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0

  lesson = .directory~new
  files = .array~new
  do while rest \= ""
    parse var rest w rest
    if w = "bottom" then parse var rest lesson~bottom rest
    else files~append(w)
  end
  if files~items < 2 then call fail "Give me two pictures or more."
  lessonsFile = home || "stitch_lessons.txt"
  ls = readLessons(lessonsFile)

  /* 1, 2: each picture -------------------------------------------- */
  pics = .array~new
  do f over files
    if \SysFileExists(f) then call fail "I can not find the picture" f"."
    pc = readPicture(f, 450, lesson)
    specks = cleanKinds(pc, 8)
    pc~blobs = blobsOf(pc, 12)
    pc~L1 = levelOf(pc, 1)
    pc~L4 = levelOf(pc, 4)
    pc~L8 = levelOf(pc, 8)
    pc~same = 0
    water = 0
    do i = 1 to pc~W * pc~H
      if pc~kinds[i] == "w" then water = water + 1
    end
    pc~water = water / (pc~W * pc~H)
    pics~append(pc)
    wl = "-"
    if pc~waterLuma \== .nil then wl = format(pc~waterLuma, , 0)
    if pc~waterRGB \== .nil then wl = wl "(one water colour:" pc~waterRGB")"
    say "  " left(pc~name, 14) pc~W "by" pc~H "cells, water brightness" wl"," format(pc~water * 100, , 0)"% water," pc~blobs~items "islands and lakes"
    call phase "read" pc~name
  end
  N = pics~items

  /* the same picture twice? ---------------------------------------- */
  do i = 1 to N
    do j = i + 1 to N
      if pics[j]~same > 0 then iterate
      if pics[i]~W = pics[j]~W & pics[i]~H = pics[j]~H then
        if pics[i]~L1~makeString("L", "") == pics[j]~L1~makeString("L", "") then do
          pics[j]~same = i
          say "  " pics[j]~name "is the same picture as" pics[i]~name
        end
    end
  end

  /* 3, 4: islands that look alike ---------------------------------- */
  links = .array~new
  linked = .array~new(N)
  do i = 1 to N
    linked[i] = 0
  end
  do i = 1 to N
    if pics[i]~same > 0 then iterate
    do j = i + 1 to N
      if pics[j]~same > 0 then iterate
      hyps = blobPairs(pics[i]~blobs, pics[j]~blobs, 0.6, 8)
      best = ""
      bs = -9
      tried = 0
      seen = .array~new
      do h over hyps
        parse var h votes k tx ty bk dk
        /* skip a guess like one already tried                        */
        dup = 0
        do s over seen
          parse var s k2 tx2 ty2 bk2
          if bk2 == bk then if abs(k2 - k) / k < 0.05 then if abs(tx2 - tx) + abs(ty2 - ty) < 4 then dup = 1
        end
        if dup then iterate
        seen~append(k tx ty bk)
        tried = tried + 1
        if tried > 6 then leave
        if bk == "A" then do; b = i; d = j; end
        else do; b = j; d = i; end
        /* first look: just here; then, if it is near, look close by  */
        r = fitAt(pics[b]~L1, pics[d]~L1, k, tx, ty, 0.01, 0, 2, 0.15)
        if r == "" then iterate
        if word(r, 1) < 0.35 then iterate
        r = fitAt(pics[b]~L1, pics[d]~L1, word(r, 2), word(r, 3), word(r, 4), 0.01, 3, 3, 0.15)
        if dbg then say "    " pics[i]~name pics[j]~name "islands:" votes "agree; zoom" k "->" r
        if word(r, 1) > bs then do
          bs = word(r, 1)
          best = r b d
        end
      end
      if best \== "" & bs >= 0.6 then if \inside(best) then do
        if dbg then say "    " pics[i]~name pics[j]~name": the closer one is not inside the wider one; no"
        best = ""
      end
      if best \== "" & bs >= 0.6 then do
        parse var best sc k tx ty ov b d
        links~append(sc k tx ty b d "islands")
        linked[b] = linked[b] + 1
        linked[d] = linked[d] + 1
        say "   fit:" pics[d]~name "in" pics[b]~name": zoom" format(k, , 3)", place" tx ty", kappa" sc "(islands)"
      end
    end
    call phase "islands" pics[i]~name
  end

  /* 5: pictures with no fit yet, then parts not yet joined: search,  */
  /* the zooms of the lessons first. A fit must keep the rule: a much */
  /* closer picture (zoom 1.5 or more) lies mostly inside the wider   */
  ks = .array~new
  do k over ls~zooms
    ks~append(k)
  end
  do k = 1.0 to 8.0 by 0.25
    ks~append(k)
  end
  do k = 8.5 to 12.0 by 0.5
    ks~append(k)
  end
  do p = 1 to N
    if pics[p]~same > 0 | linked[p] > 0 then iterate
    say "  " pics[p]~name": no island fit; searching"
    others = .array~new
    do q = 1 to N
      if q \= p & pics[q]~same = 0 then others~append(q)
    end
    found = bestSearch(pics, .array~of(p), others, ks, dbg)
    best = ""
    if found~items > 0 then best = found[1]
    if best \== "" then do
      parse var best sc k tx ty ov b d
      links~append(sc k tx ty b d "search")
      linked[b] = linked[b] + 1
      linked[d] = linked[d] + 1
      say "   fit:" pics[d]~name "in" pics[b]~name": zoom" format(k, , 3)", place" tx ty", kappa" sc "(search)"
    end
    else say "   no fit for" pics[p]~name
    call phase "search" pics[p]~name
  end
  /* parts not joined: lay each picture of the smallest part on each  */
  /* picture of the others; the best fit joins them; again till one   */
  do round = 1 to N
    part = partsOf(N, links, pics)
    if part~items <= 1 then leave
    small = part[part~items]
    rest = .array~new
    do pp = 1 to part~items - 1
      do q over part[pp]
        rest~append(q)
      end
    end
    say "  " part~items "parts; joining the part of" pics[small[1]]~name "(" small~items "pictures )"
    best = ""
    /* the smallest part first; if no fit joins it, the next one      */
    do pp = part~items to 2 by -1
      small = part[pp]
      rest = .array~new
      do qq = 1 to part~items
        if qq \= pp then do q over part[qq]
          rest~append(q)
        end
      end
      found = bestSearch(pics, small, rest, ks, dbg, 0.45)
      best = ""
      do f over found
        if word(f, 1) >= 0.6 then do
          best = f
          leave
        end
        /* nearly good: a second picture of the part, laid where this */
        /* fit says it must go, must fit too                          */
        if confirmed(f, small, links, pics, dbg) then do
          best = f
          leave
        end
      end
      if best \== "" then leave
      say "   no fit joins the part of" pics[small[1]]~name
    end
    if best == "" then leave
    parse var best sc k tx ty ov b d
    links~append(sc k tx ty b d "join")
    say "   fit:" pics[d]~name "in" pics[b]~name": zoom" format(k, , 3)", place" tx ty", kappa" sc "(join)"
    call phase "join" round
  end

  /* 6: the strongest fits that join all (a tree) -------------------- */
  links = links~sortWith(.ByFirst~new)
  grp = .array~new(N)
  do i = 1 to N
    grp[i] = i
  end
  tree = .array~new
  do l over links
    parse var l sc k tx ty b d how
    gb = top(grp, b)
    gd = top(grp, d)
    if gb = gd then iterate
    grp[gb] = gd
    tree~append(l)
  end
  /* place every picture: u(ref) = u(picture) * s + (ox, oy)          */
  s = .array~new(N)
  ox = .array~new(N)
  oy = .array~new(N)
  done = .array~new(N)
  do i = 1 to N
    done[i] = 0
  end
  parts = 0
  do start = 1 to N
    if done[start] > 0 | pics[start]~same > 0 then iterate
    parts = parts + 1
    s[start] = 1
    ox[start] = 0
    oy[start] = 0
    done[start] = parts
    more = 1
    do while more
      more = 0
      do l over tree
        parse var l sc k tx ty b d how
        if done[b] = parts & done[d] = 0 then do
          s[d] = s[b] / k
          ox[d] = tx * s[b] + ox[b]
          oy[d] = ty * s[b] + oy[b]
          done[d] = parts
          more = 1
        end
        else if done[d] = parts & done[b] = 0 then do
          s[b] = k * s[d]
          ox[b] = ox[d] - tx * k * s[d]
          oy[b] = oy[d] - ty * k * s[d]
          done[b] = parts
          more = 1
        end
      end
    end
  end
  call phase "tree"

  /* 7: words, a check picture, lessons ------------------------------ */
  call writeStitch outWords, pics, tree, s, ox, oy, done, parts, home
  do l over tree
    parse var l sc k tx ty b d how
    kk = format(round(k * 20) / 20, , 2)
    if ls~zooms[kk] == .nil then ls~zooms[kk] = 0
    ls~zooms[kk] = ls~zooms[kk] + 1
    if ls~ways[how] == .nil then ls~ways[how] = 0
    ls~ways[how] = ls~ways[how] + 1
  end
  call writeLessons lessonsFile, ls
  call phase "words"
  exit 0

top: procedure
  use arg grp, i
  do while grp[i] \= i
    i = grp[i]
  end
  return i

fail:
  raise syntax 98.900 array (arg(1))

phase:
  if pos("time", value("TOPROPE_DEBUG", , "ENVIRONMENT")) > 0 then say "  time:" left(arg(1), 24) format(time("E"), , 1) "s"
  return

seeError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "SLAM stitch stopped." co["ADDITIONAL"][1]
  else say "SLAM stitch broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  exit 2

::requires "stitch.cls"

/* a much closer picture lies mostly inside the wider one             */
/* f: "kappa k tx ty overlap ..."                                     */
::routine inside
  use arg f
  parse var f sc k tx ty ov .
  if k >= 1.5 then return ov >= 0.6
  return .true

/* the best fit between a picture of "these" and a picture of         */
/* "those", both ways round; "" when none is good enough              */
::routine bestSearch
  use arg pics, these, those, ks, dbg, need = 0.6
  found = .array~new
  do p over these
    do q over those
      do ord over .array~of(q p, p q)
        parse var ord b d
        cands = .array~new
        do k over ks
          /* cells of 8; when the closer picture would be too few      */
          /* cells across, cells of 4                                  */
          lv = 8
          if pics[d]~W / k / 8 < 12 then lv = 4
          if lv = 8 then do; Lb = pics[b]~L8; Ld = pics[d]~L8; end
          else do; Lb = pics[b]~L4; Ld = pics[d]~L4; end
          sm = resample(Ld, k)
          if sm~items < 3 then iterate
          if length(sm[1]) < 3 then iterate
          top = search(Lb, sm, 1 - length(sm[1]), length(Lb[1]) - 1, 1 - sm~items, Lb~items - 1, 0.3)
          /* the rule, already in the low pass: a much closer picture  */
          /* lies mostly inside the wider one                          */
          do t over top
            parse var t sc tx ty ov
            if inside(sc k tx ty ov) then cands~append(t k lv)
          end
        end
        cands = cands~sortWith(.ByFirst~new)
        do c = 1 to min(4, cands~items)
          parse value cands[c] with sc tx ty ov k lv
          m = 8 / lv
          r = fitAt(pics[b]~L4, pics[d]~L4, k, tx * 2 / m, ty * 2 / m, 0.02, 3, 3, 0.25)
          if r == "" then iterate
          parse var r sc k tx ty ov
          r = fitAt(pics[b]~L1, pics[d]~L1, k, tx * 4, ty * 4, 0.01, 3, 5, 0.25)
          if r == "" then iterate
          ok = inside(r)
          note = ""
          if \ok then note = "(not inside the wider one: no)"
          if dbg then say "    search" pics[d]~name "in" pics[b]~name": low" cands[c] "->" r note
          if \ok then iterate
          if word(r, 1) >= need then found~append(r b d)
        end
      end
    end
  end
  return found~sortWith(.ByFirst~new)

/* a nearly good fit "sc k tx ty ov b d" joins part "small". Lay each */
/* other picture m of the part where the fit says it must be; it is   */
/* confirmed when one of them fits there with kappa 0.5 or more       */
::routine confirmed
  use arg best, small, links, pics, dbg
  parse var best sc bigK fitX fitY ov b d
  /* x: the picture of the fit that is in the small part              */
  if small~hasItem(d) then x = d
  else if small~hasItem(b) then x = b
  else return .false
  /* where each picture m of the part is, in x: u(x) = u(m) * s + o   */
  s = .directory~new
  ox = .directory~new
  oy = .directory~new
  s[x] = 1
  ox[x] = 0
  oy[x] = 0
  more = 1
  do while more
    more = 0
    do l over links
      parse var l lsc lk ltx lty lb ld how
      /* u(lb) = u(ld) / lk + t                                       */
      if s[lb] \== .nil & s[ld] == .nil then do
        s[ld] = s[lb] / lk
        ox[ld] = ltx * s[lb] + ox[lb]
        oy[ld] = lty * s[lb] + oy[lb]
        more = 1
      end
      else if s[ld] \== .nil & s[lb] == .nil then do
        s[lb] = lk * s[ld]
        ox[lb] = ox[ld] - ltx * lk * s[ld]
        oy[lb] = oy[ld] - lty * lk * s[ld]
        more = 1
      end
    end
  end
  do m over small
    if m = x | s[m] == .nil then iterate
    if x = d then do
      /* u(b) = u(x) / K + T = u(m) * s / K + o / K + T: m in b        */
      wide = b
      near = m
      km = bigK / s[m]
      tx = ox[m] / bigK + fitX
      ty = oy[m] / bigK + fitY
    end
    else do
      /* u(x) = u(d) / K + T and u(x) = u(m) * s + o, so               */
      /* u(m) = u(d) / (K s) + (T - o) / s: d in m                     */
      wide = m
      near = d
      km = bigK * s[m]
      tx = (fitX - ox[m]) / s[m]
      ty = (fitY - oy[m]) / s[m]
    end
    if km < 0.99 then iterate
    r = fitAt(pics[wide]~L1, pics[near]~L1, km, tx, ty, 0.01, 2, 4, 0.25)
    if dbg then say "    confirm:" pics[near]~name "in" pics[wide]~name "at zoom" format(km, , 3) "->" r
    if r \== "" then if word(r, 1) >= 0.5 then return .true
  end
  return .false

/* the parts (pictures joined by fits), biggest first                 */
::routine partsOf
  use arg N, links, pics
  grp = .array~new(N)
  do i = 1 to N
    grp[i] = i
  end
  do l over links
    parse var l sc k tx ty b d how
    gb = b
    do while grp[gb] \= gb
      gb = grp[gb]
    end
    gd = d
    do while grp[gd] \= gd
      gd = grp[gd]
    end
    if gb \= gd then grp[gb] = gd
  end
  byTop = .directory~new
  do i = 1 to N
    if pics[i]~same > 0 then iterate
    t = i
    do while grp[t] \= t
      t = grp[t]
    end
    if byTop[t] == .nil then byTop[t] = .array~new
    byTop[t]~append(i)
  end
  out = .array~new
  do t over byTop
    out~append(byTop[t])
  end
  /* biggest first */
  do i = 1 to out~items
    do j = i + 1 to out~items
      if out[j]~items > out[i]~items then do
        tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      end
    end
  end
  return out

/* where each picture goes, in the full places of the frame picture   */
::routine writeStitch
  use arg outFile, pics, tree, s, ox, oy, done, parts, home
  N = pics~items
  call SysFileDelete outFile
  call lineout outFile, "-- How the pictures fit together, found by SLAM (stitch.rex)."
  call lineout outFile, "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5)."
  call lineout outFile, "-- Each fit: water laid on water; kappa 1 is a perfect fit, 0 is chance."
  call lineout outFile, ""
  do part = 1 to parts
    /* the frame: the widest picture in this part (biggest s)          */
    R = 0
    do i = 1 to N
      if done[i] \= part | pics[i]~same > 0 then iterate
      if R = 0 then R = i
      else if s[i] > s[R] then R = i
    end
    fR = pics[R]~f
    call lineout outFile, "stitch part" part
    call lineout outFile, "  frame" pics[R]~name "-- every place below is in its places, before any cut"
    minX = 0
    minY = 0
    maxX = 0
    maxY = 0
    place = .array~new(N)
    do i = 1 to N
      if done[i] \= part | pics[i]~same > 0 then iterate
      sc = fR * s[i] / (pics[i]~f * s[R])
      x = fR * (ox[i] - ox[R]) / s[R]
      y = fR * (oy[i] - oy[R]) / s[R]
      w = pics[i]~fullW * sc
      h = pics[i]~fullH * sc
      place[i] = x y w h sc
      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x + w)
      maxY = max(maxY, y + h)
    end
    do i = 1 to N
      if place[i] == .nil then iterate
      parse value place[i] with x y w h sc
      how = ""
      do l over tree
        parse var l k1 k2 k3 k4 b d hw
        if d = i | b = i then if how == "" then how = "(kappa" k1"," hw")"
      end
      call lineout outFile, "  picture" left(pics[i]~name, 12) "at" format(x, , 1) format(y, , 1) ,
                            "size" format(w, , 1) "by" format(h, , 1) "--" format(1 / sc, , 3) "times closer" how
    end
    do i = 1 to N
      if pics[i]~same > 0 then if done[pics[i]~same] = part then
        call lineout outFile, "  picture" left(pics[i]~name, 12) "is" pics[pics[i]~same]~name "-- the same picture"
    end
    call lineout outFile, "end"
    call lineout outFile, ""
    /* a check picture: ImageMagick lays them down, widest first       */
    order = .array~new
    do i = 1 to N
      if place[i] \== .nil then order~append(format(place[i]~word(5), , 6) i)
    end
    order = order~sortWith(.ByFirst~new)
    cw = trunc(maxX - minX + 1)
    chh = trunc(maxY - minY + 1)
    out = "stitched_part" || part || ".png"
    cmd = 'convert -size' cw'x'chh 'xc:"#202020"'
    do o over order
      i = word(o, 2)
      parse value place[i] with x y w h sc
      geo = trunc(w + 0.5) || "x" || trunc(h + 0.5) || "!"
      at = "+" || trunc(x - minX) || "+" || trunc(y - minY)
      crop = pics[i]~fullW || "x" || pics[i]~fullH || "+0+0"
      cmd = cmd '\(' '"'pics[i]~file'"' '-crop' crop '+repage -resize' geo '\)' '-geometry' at '-composite'
    end
    do o over order
      i = word(o, 2)
      parse value place[i] with x y w h sc
      x0 = trunc(x - minX)
      y0 = trunc(y - minY)
      x1 = trunc(x - minX + w)
      y1 = trunc(y - minY + h)
      cmd = cmd '-fill none -stroke yellow -strokewidth 2 -draw "rectangle' x0','y0 x1','y1'"'
      cmd = cmd '-fill yellow -stroke none -pointsize 22 -annotate +'x0 + 6'+'y0 + 24 '"'pics[i]~name'"'
    end
    cmd = cmd '"'out'"'
    address system cmd
    say "   part" part": frame" pics[R]~name"," order~items "pictures ->" out "(" cw "by" chh ")"
  end
  call lineout outFile
  return
