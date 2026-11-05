/* ------------------------------------------------------------------ */
/* cbd_blocks_cut_bridge.rex -- take the Harbour Bridge out of the    */
/*   LiDAR block file                                                 */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx cbd_blocks_cut_bridge.rex in.words out.words                  */
/*                                                                    */
/* The Bridge (deck, arch, pylons, abutments) is the scene's own      */
/* model. Seen from above, LiDAR cannot tell a deck or an arch from a */
/* roof, so its blocks there stand from the water to the deck as      */
/* solid walls. Every block whose box touches the Bridge zone         */
/* (.HarbourCbdBlocks~bridgeZone) is left out; the ids left out are   */
/* listed in out.words. The loader applies the same zone again.       */
/* ------------------------------------------------------------------ */
parse arg fin fout .
if fout = "" then do
  say "usage: rexx cbd_blocks_cut_bridge.rex in.words out.words"
  exit 2
end
pano = .HarbourOcclusionPanorama~new
cfg = pano~configure
scene = pano~scene
zone = .HarbourCbdBlocks~bridgeZone(scene)
if zone == .nil then do; say "no abutments in the scene"; exit 1; end
keep = .array~new; cut = .array~new; head = .array~new
do while lines(fin) > 0
  l = linein(fin)
  if word(l, 1) \== "block" then do
    if pos("Bridge zone", l) = 0 then head~append(l)
    iterate
  end
  parse var l "block" id "scene" x y "size" len "by" wid "bearing" b .
  ux = RxCalcSin(b, 12, "D"); uy = RxCalcCos(b, 12, "D")
  box = scene~cuboid("CBD_" || id, x, y, 0, len, wid, 1, ux, uy, uy, -ux)
  if .HarbourCbdBlocks~overlaps(.HarbourCbdBlocks~footprintOf(box), zone) then cut~append(id~strip)
  else keep~append(l)
end
call stream fin, "c", "close"
call SysFileDelete fout
do i = 1 to head~items
  l = head[i]
  if word(l, 1) == "scene" & word(l, 2) == "blocks" then do
    call lineout fout, "-- Bridge zone (deck, arch, pylons, abutments; .HarbourCbdBlocks~bridgeZone) is the scene's own:"
    call lineout fout, "-- " cut~items "LiDAR blocks touching it left out by cbd_blocks_cut_bridge.rex:"
    ids = ""
    do j = 1 to cut~items
      ids = ids cut[j]
      if length(ids) > 90 then do; call lineout fout, "--  ids" ids; ids = ""; end
    end
    if ids \= "" then call lineout fout, "--  ids" ids
  end
  call lineout fout, l
end
do l over keep; call lineout fout, l; end
call stream fout, "c", "close"
say "Bridge zone: middle" format(zone[2], , 1) format(zone[3], , 1) ,
    "length" format(RxCalcSqrt(zone[6] ** 2 + zone[7] ** 2, 8), , 0) "width" format(RxCalcSqrt(zone[8] ** 2 + zone[9] ** 2, 8), , 0)
say "kept" keep~items "blocks, left out" cut~items "on the Bridge; wrote" fout
exit 0
::requires "SlamHarbourTerrain.cls"
::requires "SlamHarbourWordsScene.cls"
::requires "SlamHarbourCbdBlocks.cls"
::requires "rxmath" LIBRARY
