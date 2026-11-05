/* ------------------------------------------------------------------ */
/* cbd_blocks_check.rex -- the CBD blocks in Power SLAM's scene: no   */
/*   block left inside a named solid, and the counts                  */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx cbd_blocks_check.rex cbd_scene_blocks.words [minHeight]       */
/* ------------------------------------------------------------------ */
parse arg file minH .
if file = "" then do
  say "usage: rexx cbd_blocks_check.rex cbd_scene_blocks.words [minHeight]"
  exit 2
end
if minH = "" then minH = 3
pano = .HarbourOcclusionPanorama~new
cfg = pano~configure
scene = pano~scene
named = scene~boxes~items
r = .HarbourCbdBlocks~apply(scene, file, minH)
say "named solids:" named "  blocks added:" r["BLOCKS"] "  under" minH "m:" r["SKIPPED"] "  duplicates left out:" r["INSIDE_NAMED"]
do k over r["NAMED_HITS"]~allIndexes~sort
  say "   " left(k, 24) r["NAMED_HITS"][k]
end
/* the check: no added block's middle inside a named solid, and no    */
/* named solid's middle inside an added block                         */
bad = 0
marks = .array~new
do i = 1 to named; marks~append(.HarbourCbdBlocks~footprintOf(scene~boxes[i])); end
do i = named + 1 to scene~boxes~items
  me = .HarbourCbdBlocks~footprintOf(scene~boxes[i])
  do m over marks
    if .HarbourCbdBlocks~holds(m, me[2], me[3]) | .HarbourCbdBlocks~holds(me, m[2], m[3]) then do
      bad += 1; say "FAIL" me[1] "overlaps" m[1]
    end
  end
end
/* known answer: a block placed on Salesforce's middle must be left out */
probe = "/tmp/cbd_probe.words"
call SysFileDelete probe
call lineout probe, "  block 99999 scene -125 -1149 size 20 by 20 bearing 0 base 2 top 102 height 100 area 400"
call lineout probe, "  block 99998 scene 1400 -3000 size 20 by 20 bearing 0 base 2 top 102 height 100 area 400"
call stream probe, "c", "close"
pano2 = .HarbourOcclusionPanorama~new; cfg2 = pano2~configure
r2 = .HarbourCbdBlocks~apply(pano2~scene, probe, 3)
ok = r2["BLOCKS"] = 1 & r2["INSIDE_NAMED"] = 1
say "known answer (one block on Salesforce, one in the open):" word("FAIL PASS", 1 + ok)
if bad = 0 & ok then say "PASS no CBD block inside a named solid"
else say "FAIL" bad "overlaps"
exit (bad > 0 | \ok)
::requires "SlamHarbourTerrain.cls"
::requires "SlamHarbourWordsScene.cls"
::requires "SlamHarbourCbdBlocks.cls"
::requires "rxmath" LIBRARY
