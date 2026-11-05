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
/* landmark refinement reads. Call apply after the scene is built.    */
/* Returns a directory: BLOCKS added, SKIPPED (low), INSIDE_NAMED     */
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
  r["INSIDE_NAMED"] = dupes; r["NAMED_HITS"] = hits
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

/* does footprint f hold the point x y                                */
::method holds class
  use strict arg f, x, y
  px = x - f[4]; py = y - f[5]
  aa = f[6] * f[6] + f[7] * f[7]; bb = f[8] * f[8] + f[9] * f[9]
  if aa = 0 | bb = 0 then return .false
  s = (px * f[6] + py * f[7]) / aa
  t = (px * f[8] + py * f[9]) / bb
  return s >= 0 & s <= 1 & t >= 0 & t <= 1
