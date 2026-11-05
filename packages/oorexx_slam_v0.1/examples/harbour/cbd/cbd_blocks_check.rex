/* ------------------------------------------------------------------ */
/* cbd_blocks_check.rex -- the CBD blocks in Power SLAM's scene: no   */
/*   block left inside a named solid or touching the Harbour Bridge,  */
/*   the named solids unchanged, and the counts                       */
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
say "named solids:" named "  blocks added:" r["BLOCKS"] "  under" minH "m:" r["SKIPPED"] "  on the Bridge:" r["BRIDGE_ZONE"] "  duplicates left out:" r["INSIDE_NAMED"]
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
/* the Bridge stays the scene's own: no CBD block touches its zone,   */
/* and the named Bridge solids are all still there, unchanged          */
zone = .HarbourCbdBlocks~bridgeZone(scene)
onB = 0
do i = named + 1 to scene~boxes~items
  me = .HarbourCbdBlocks~footprintOf(scene~boxes[i])
  if .HarbourCbdBlocks~overlaps(me, zone) then do; onB += 1; say "FAIL" me[1] "touches the Bridge zone"; end
end
bridgeNames = 0
do i = 1 to named
  nm = scene~boxes[i][1]
  if abbrev(nm, "ABUTMENT") | abbrev(nm, "PYLON") | nm == "DECK" | pos("ARCH", nm) > 0 then bridgeNames += 1
end
fresh = .HarbourOcclusionPanorama~new; cfgF = fresh~configure
same = fresh~scene~boxes~items = named
do i = 1 to named while same
  a1 = scene~boxes[i]; b1 = fresh~scene~boxes[i]
  if a1[1] \== b1[1] then same = .false
  else do v = 1 to 8
    if a1[2][v][1] \= b1[2][v][1] | a1[2][v][2] \= b1[2][v][2] | a1[2][v][3] \= b1[2][v][3] then same = .false
  end
end
say "Bridge zone: CBD blocks touching it:" onB "  named Bridge solids:" bridgeNames "  named solids unchanged:" word("no yes", 1 + same)
bad = bad + onB + \same
/* with the arch (SlamHarbourBridgeArch, as SLAM 450 loads it): every */
/* arch solid lies inside the Bridge zone, and no CBD block touches it */
pA = .HarbourOcclusionPanorama~new; cfgA = pA~configure
nArch = .HarbourBridgeArch~apply(pA~scene)
namedA = pA~scene~boxes~items
rA = .HarbourCbdBlocks~apply(pA~scene, file, minH)
zA = .HarbourCbdBlocks~bridgeZone(pA~scene)
archOut = 0; archHit = 0
do i = 1 to namedA
  f = .HarbourCbdBlocks~footprintOf(pA~scene~boxes[i])
  if pos("ARCH", f[1]) = 0 then iterate
  do a = 0 to 1
    do c = 0 to 1
      if \.HarbourCbdBlocks~holds(zA, f[4] + a * f[6] + c * f[8], f[5] + a * f[7] + c * f[9]) then archOut += 1
    end
  end
  do j = namedA + 1 to pA~scene~boxes~items
    if .HarbourCbdBlocks~overlaps(.HarbourCbdBlocks~footprintOf(pA~scene~boxes[j]), f) then archHit += 1
  end
end
say "with the arch:" nArch "arch solids; corners outside the Bridge zone:" archOut "  CBD blocks touching an arch solid:" archHit "  blocks added:" rA["BLOCKS"]
bad = bad + archOut + archHit
/* known answer: block 441 as it was (481 by 12 m along the span, its  */
/* middle outside the deck) must be left out on the Bridge             */
probeB = "/tmp/cbd_probe_bridge.words"
call SysFileDelete probeB
call lineout probeB, "  block 441 scene 85.2 -32.4 size 481 by 12 bearing 27.9 base 1.1 top 61.3 height 60.2 area 3536"
call stream probeB, "c", "close"
pano3 = .HarbourOcclusionPanorama~new; cfg3 = pano3~configure
r3 = .HarbourCbdBlocks~apply(pano3~scene, probeB, 3)
okB = r3["BLOCKS"] = 0 & r3["BRIDGE_ZONE"] = 1
say "known answer (old block 441, a wall under the deck):" word("FAIL PASS", 1 + okB)
bad = bad + \okB
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
if bad = 0 & ok then say "PASS no CBD block inside a named solid or on the Bridge"
else say "FAIL" bad "overlaps"
exit (bad > 0 | \ok)
::requires "SlamHarbourTerrain.cls"
::requires "SlamHarbourWordsScene.cls"
::requires "SlamHarbourCbdBlocks.cls"
::requires "SlamHarbourBridgeArch.cls"
::requires "rxmath" LIBRARY
