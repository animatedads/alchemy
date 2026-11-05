/* ------------------------------------------------------------------ */
/* SlamHarbourCbdBlocks.cls -- the Sydney CBD's buildings, measured by */
/*   LiDAR, as Power SLAM cuboids                                     */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5), for ChatGPT's Power SLAM scene   */
/* Data         : NSW Government LiDAR (DCCEEW Marine LiDAR, August   */
/*                2018), CC BY 4.0, by las_grid.rex, lidar_mosaic.rex, */
/*                lidar_blocks.rex, cbd_blocks_scene.rex               */
/*                                                                    */
/* .HarbourCbdBlocks~apply(scene, file [, minHeight]) adds one cuboid */
/* per block of the scene words, using the scene's own cuboid:        */
/*   cuboid('CBD_<id>', x, y, base, long, wide, height, ux, uy, vx, vy) */
/* with u along the block's bearing (true north, clockwise) and v     */
/* across it, v = (uy, -ux), as SlamHarbourWharves.cls does.          */
/* Blocks lower than minHeight (default 3 m) are left out. So is any  */
/* block that duplicates a solid already in the scene (the named      */
/* landmarks, wharves, station, Cahill, bridge): its middle is inside */
/* that solid's footprint, or that solid's middle is inside the       */
/* block's. The named solid wins, so its known top stays the one the  */
/* landmark refinement reads. No block may touch the Harbour Bridge's */
/* zone (bridgeZone: abutment to abutment, pylons, arch and deck, 15 m */
/* spare): the Bridge stays the scene's own model, never LiDAR.        */
/* Call apply after the scene is built; it stops if the scene has no   */
/* abutments.                                                          */
/* Returns a directory: BLOCKS added, SKIPPED (low), BRIDGE_ZONE (left */
/* out on the Bridge), INSIDE_NAMED                                    */
/* (duplicates left out), NAMED_HITS (solid name -> count), SOURCE,   */
/* STATUS.                                                             */
/* The heights are measured, not estimated; the footprint is a box    */
/* round the block's 2 m cells (not a surveyed outline). August 2018: */
/* towers built since (Crown Sydney, Quay Quarter Tower, Greenland    */
/* Centre) are missing or part-built.                                  */
/* ------------------------------------------------------------------ */
::requires "rxmath" LIBRARY

::class HarbourCbdBlocks public
::method apply class
  use strict arg scene, file, minHeight = 3
  added = 0; skipped = 0; dupes = 0
  /* the named solids already in the scene: their footprints          */
  marks = .array~new
  do bx over scene~boxes
    marks~append(self~footprintOf(bx))
  end
  /* the Harbour Bridge is the scene's own (deck, arch, pylons,        */
  /* abutments): no LiDAR block may touch its zone                     */
  zone = self~bridgeZone(scene)
  if zone == .nil then raise syntax 93.900 array ("HarbourCbdBlocks: no ABUTMENT_S/ABUTMENT_N in the scene, so the Bridge zone is unknown; load the blocks after the scene is built")
  onBridge = 0
  hits = .directory~new
  do while lines(file) > 0
    l = linein(file)~strip
    if word(l, 1) \== "block" then iterate
    parse var l "block" id "scene" x y "size" len "by" wid "bearing" b "base" base "top" . "height" h .
    if h < minHeight then do; skipped += 1; iterate; end
    ux = RxCalcSin(b, 12, "D"); uy = RxCalcCos(b, 12, "D")
    vx = uy; vy = -ux
    box = scene~cuboid("CBD_" || id, x, y, base, len, wid, h, ux, uy, vx, vy)
    me = self~footprintOf(box)
    if self~overlaps(me, zone) then do; onBridge += 1; iterate; end
    hit = ""
    do m over marks
      if self~holds(m, x, y) | self~holds(me, m[2], m[3]) then do; hit = m[1]; leave; end
    end
    if hit \== "" then do
      dupes += 1
      if hits~hasIndex(hit) then hits[hit] = hits[hit] + 1; else hits[hit] = 1
      iterate
    end
    scene~boxes~append(box)
    added += 1
  end
  call stream file, "c", "close"
  r = .directory~new
  r["BLOCKS"] = added; r["SKIPPED"] = skipped; r["SOURCE"] = filespec("name", file)
  r["INSIDE_NAMED"] = dupes; r["NAMED_HITS"] = hits; r["BRIDGE_ZONE"] = onBridge
  r["STATUS"] = "LIDAR_MEASURED_HEIGHTS_BOXED_FOOTPRINTS_AUG2018"
  return r

/* a box's footprint: name, middle x y, corner, and its two sides     */
::method footprintOf class
  use strict arg box
  v = box[2]
  ax = v[3][1] - v[1][1]; ay = v[3][2] - v[1][2]
  bx = v[2][1] - v[1][1]; by = v[2][2] - v[1][2]
  return .array~of(box[1], (v[1][1] + v[4][1]) / 2, (v[1][2] + v[4][2]) / 2, ,
                   v[1][1], v[1][2], ax, ay, bx, by)

/* the Bridge zone: from ABUTMENT_S to ABUTMENT_N, each end carried   */
/* on past its abutment by half the abutment's length plus SPARE, and  */
/* across by the wider of the abutment and the deck, plus SPARE each   */
/* side. Pylons stand on the abutments, the arch springs from them and */
/* the deck runs between them, so the zone holds the whole Bridge.     */
/* Returns a footprint, or .nil if the scene has no abutments.         */
::method bridgeZone class
  use strict arg scene, spare = 15
  s = .nil; n = .nil; deckHalf = 0
  do bx over scene~boxes
    if bx[1] == "ABUTMENT_S" then s = self~footprintOf(bx)
    if bx[1] == "ABUTMENT_N" then n = self~footprintOf(bx)
    if bx[1] == "DECK" then do
      f = self~footprintOf(bx)
      deckHalf = max(deckHalf, RxCalcSqrt(f[8] * f[8] + f[9] * f[9], 10) / 2)
    end
  end
  if s == .nil | n == .nil then return .nil
  dx = n[2] - s[2]; dy = n[3] - s[3]
  span = RxCalcSqrt(dx * dx + dy * dy, 10)
  ux = dx / span; uy = dy / span; vx = uy; vy = -ux
  /* the abutment's sides: the one along the span is its length        */
  la = RxCalcSqrt(s[6] * s[6] + s[7] * s[7], 10); lb = RxCalcSqrt(s[8] * s[8] + s[9] * s[9], 10)
  if abs(s[6] * ux + s[7] * uy) / la >= abs(s[8] * ux + s[9] * uy) / lb then do; along = la; across = lb; end
  else do; along = lb; across = la; end
  ends = along / 2 + spare
  half = max(across / 2, deckHalf) + spare
  cx = s[2] - ux * ends - vx * half; cy = s[3] - uy * ends - vy * half
  long = span + 2 * ends
  return .array~of("BRIDGE_ZONE", (s[2] + n[2]) / 2, (s[3] + n[3]) / 2, ,
                   cx, cy, ux * long, uy * long, vx * 2 * half, vy * 2 * half)

/* do two footprints overlap (separating axes: each one's two sides)  */
::method overlaps class
  use strict arg f, g
  do axis over .array~of(.array~of(f[6], f[7]), .array~of(f[8], f[9]), ,
                         .array~of(g[6], g[7]), .array~of(g[8], g[9]))
    ax = axis[1]; ay = axis[2]
    if ax = 0 & ay = 0 then iterate
    parse value self~spread(f, ax, ay) with fl fh
    parse value self~spread(g, ax, ay) with gl gh
    if fh < gl | gh < fl then return .false
  end
  return .true

/* a footprint's lowest and highest projection on an axis              */
::method spread class
  use strict arg f, ax, ay
  lo = 1e30; hi = -1e30
  do a = 0 to 1
    do b = 0 to 1
      px = f[4] + a * f[6] + b * f[8]; py = f[5] + a * f[7] + b * f[9]
      p = px * ax + py * ay
      lo = min(lo, p); hi = max(hi, p)
    end
  end
  return lo hi

/* does footprint f hold the point x y                                */
::method holds class
  use strict arg f, x, y
  px = x - f[4]; py = y - f[5]
  aa = f[6] * f[6] + f[7] * f[7]; bb = f[8] * f[8] + f[9] * f[9]
  if aa = 0 | bb = 0 then return .false
  s = (px * f[6] + py * f[7]) / aa
  t = (px * f[8] + py * f[9]) / bb
  return s >= 0 & s <= 1 & t >= 0 & t <= 1
