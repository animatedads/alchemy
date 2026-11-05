/* ------------------------------------------------------------------ */
/* render_view.rex -- Power SLAM's scene drawn from a camera, to set  */
/*   beside a photo                                                   */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx render_view.rex heights.words water.words blocks.words out.svg */
/*      x y z heading tilt fov [width height]                         */
/*   x y z     camera, scene metres (z: metres AHD)                   */
/*   heading   degrees clockwise from north; tilt: degrees, down < 0  */
/*   fov       horizontal field of view, degrees                      */
/*                                                                    */
/* Ground: each 50 m cell of the heights grid as a flat-shaded square  */
/* at its four corner heights, water blue at its own level. Then every */
/* box of the configured scene and the CBD blocks, far ones first,    */
/* each face shaded by which way it faces. No sky model, no textures: */
/* the shapes and the skyline are what to compare.                    */
/* ------------------------------------------------------------------ */
parse arg hFile wFile bFile out cx cy cz hd tl fov W H .
if fov = "" then do
  say "usage: rexx render_view.rex heights.words water.words blocks.words out.svg x y z heading tilt fov [w h]"
  exit 2
end
if W = "" then W = 1600
if H = "" then H = 900
numeric digits 14
d2r = RxCalcPi(14) / 180
sh = RxCalcSin(hd * d2r, 12, "R"); ch = RxCalcCos(hd * d2r, 12, "R")
st = RxCalcSin(tl * d2r, 12, "R"); ct = RxCalcCos(tl * d2r, 12, "R")
/* camera axes: forward, right, up                                     */
fx = sh * ct; fy = ch * ct; fz = st
rx = ch; ry = -sh; rz = 0
ux = ry * fz - rz * fy; uy = rz * fx - rx * fz; uz = rx * fy - ry * fx
fpx = (W / 2) / RxCalcTan(fov / 2 * d2r, 12, "R")
cam = .array~of(cx, cy, cz, fx, fy, fz, rx, ry, rz, ux, uy, uz, fpx, W, H)

/* the scene: ChatGPT's boxes, then the CBD blocks                    */
pano = .HarbourOcclusionPanorama~new
cfg = pano~configure
scene = pano~scene
if bFile \== "-" then r = .HarbourCbdBlocks~apply(scene, bFile)

faces = .array~new
/* ground                                                              */
tile = .HarbourWordsSceneTile~new(.HarbourWordsMGA~new(hFile), 0.9)
fit = .FrameFit~new(tile)
parse value gridOf(hFile) with gE0 gN0 gStep nCols nRows
hts = .array~new
do while lines(hFile) > 0
  l = linein(hFile)~strip
  if l~left(4) == "row " then hts~append(l~substr(5))
end
call stream hFile, "c", "close"
wat = .array~new
do while lines(wFile) > 0
  l = linein(wFile)~strip
  if l~left(4) == "row " then wat~append(l~substr(5)~strip)
end
call stream wFile, "c", "close"
do rr = 1 to nRows - 1
  r1 = hts[rr]; r2 = hts[rr + 1]
  do cc = 1 to nCols - 1
    p = fit~scene(gE0 + (cc - 1 + 0.5) * gStep, gN0 - (rr - 1 + 0.5) * gStep)
    dx = p[1] - cx; dy = p[2] - cy
    if dx * fx + dy * fy < 20 then iterate               /* behind      */
    if dx * dx + dy * dy > 6000 ** 2 then iterate
    isW = wat[rr]~subchar(cc) == "W"
    hs = word(r1, cc) word(r1, cc + 1) word(r2, cc + 1) word(r2, cc)
    if verify(hs, "0123456789.- ") > 0 | pos(" - ", " "hs" ") > 0 then iterate
    pts = .array~new
    k = 0
    do q over .array~of("0 0", "1 0", "1 1", "0 1")
      parse var q a b
      k += 1
      z = word(hs, k); if isW then z = 0
      s = fit~scene(gE0 + (cc - 1 + a) * gStep, gN0 - (rr - 1 + b) * gStep)
      pts~append(.array~of(s[1], s[2], z))
    end
    if isW then col = "#5d8fb3"; else col = landColour(word(hs, 1))
    call addFace faces, pts, col, cam, isW
  end
end
nGround = faces~items
/* boxes: 8 corners in cuboid order; sides then top                    */
nBox = 0
do b over scene~boxes
  v = b[2]
  nBox += 1
  col = boxColour(b[1])
  do f over .array~of("1 2 6 5", "3 4 8 7", "1 3 7 5", "2 4 8 6", "5 6 8 7")
    pts = .array~new
    do i over f~makeArray(" "); pts~append(v[i]); end
    call addFace faces, pts, col, cam, 0
  end
end
say "faces: ground" nGround", boxes" nBox "->" faces~items - nGround "faces"

/* far first                                                          */
faces = faces~sortWith(.FarFirst~new)
call SysFileDelete out
call lineout out, '<svg xmlns="http://www.w3.org/2000/svg" width="' || W || '" height="' || H || '">'
call lineout out, '<rect width="100%" height="100%" fill="#c9dcec"/>'
do f over faces
  call lineout out, '<polygon points="' || f[2] || '" fill="' || f[3] || '" stroke="' || f[3] || '" stroke-width="0.6"/>'
end
call lineout out, '<text x="12" y="' || H - 28 || '" font-family="DejaVu Sans" font-size="13" fill="#123">Power SLAM scene from camera' ,
  cx cy cz "heading" hd "tilt" tl "fov" fov '. Ground: NSW Spatial Services DEM; blocks: NSW Government LiDAR (Aug 2018), CC BY 4.0.</text>'
call lineout out, '<text x="12" y="' || H - 10 || '" font-family="DejaVu Sans" font-size="13" fill="#123">Architecture: Tom Dyer. Power SLAM scene: ChatGPT. Blocks, water and this drawing: Claude (Opus 5.5), native ooRexx 5.3.0.</text>'
call lineout out, '</svg>'
call stream out, "c", "close"
say "wrote" out
exit 0

/* project one face; keep it if all its corners are in front         */
::routine addFace
  use arg faces, pts, col, cam, flat
  parse value cam~makeString("L", " ") with cx cy cz fx fy fz rx ry rz ux uy uz fpx W H
  s = ""; dsum = 0; n = 0
  nx = 0; ny = 0; nz = 0
  do p over pts
    dx = p[1] - cx; dy = p[2] - cy; dz = p[3] - cz
    df = dx * fx + dy * fy + dz * fz
    if df < 1 then return
    sx = W / 2 + fpx * (dx * rx + dy * ry + dz * rz) / df
    sy = H / 2 - fpx * (dx * ux + dy * uy + dz * uz) / df
    if abs(sx) > 4 * W | abs(sy) > 4 * H then return
    s = s format(sx, , 1)","format(sy, , 1)
    dsum += dx * dx + dy * dy + dz * dz; n += 1
  end
  /* shade by the face's normal: light from the north-west, above     */
  p1 = pts[1]; p2 = pts[2]; p3 = pts[3]
  ax = p2[1] - p1[1]; ay = p2[2] - p1[2]; az = p2[3] - p1[3]
  bx = p3[1] - p1[1]; by = p3[2] - p1[2]; bz = p3[3] - p1[3]
  nx = ay * bz - az * by; ny = az * bx - ax * bz; nz = ax * by - ay * bx
  nl = RxCalcSqrt(nx * nx + ny * ny + nz * nz, 12)
  if nl = 0 then shade = 1
  else do
    lit = abs(nx * -0.45 + ny * 0.55 + nz * 0.70) / nl
    shade = 0.55 + 0.45 * lit
  end
  if flat then shade = 1
  faces~append(.array~of(dsum / n, strip(s), dim(col, shade)))
  return

::routine dim
  use arg col, k
  r = x2d(substr(col, 2, 2)) * k; g = x2d(substr(col, 4, 2)) * k; b = x2d(substr(col, 6, 2)) * k
  return "#" || d2x(trunc(min(255, r)), 2) || d2x(trunc(min(255, g)), 2) || d2x(trunc(min(255, b)), 2)

::routine landColour
  use arg h
  if h < 10 then return "#8c9a7c"
  if h < 30 then return "#7f9070"
  return "#748564"

::routine boxColour
  use arg name
  if name~left(4) == "CBD_" then return "#d9d4c8"
  if name == "OPERA" then return "#f3eedc"
  if name == "DECK" | name~left(5) == "PYLON" | name~left(8) == "ABUTMENT" then return "#5a5f66"
  if name~left(6) == "CAHILL" then return "#8b6a4a"
  return "#b9b0a0"

::routine gridOf
  use arg file
  do while lines(file) > 0
    l = linein(file)~strip
    if l~left(9) == "grid mga " then do
      parse var l "grid mga" . "top left" e0 n0 "step" st "across" nc "down" nr .
      call stream file, "c", "close"
      return e0 n0 st nc nr
    end
  end

::class FarFirst
::method compare
  use arg a, b
  if a[1] > b[1] then return -1
  if a[1] < b[1] then return 1
  return 0

::requires "SlamHarbourTerrain.cls"
::requires "SlamHarbourWordsScene.cls"
::requires "harbour_frame.cls"
::requires "SlamHarbourCbdBlocks.cls"
::requires "rxmath" LIBRARY
