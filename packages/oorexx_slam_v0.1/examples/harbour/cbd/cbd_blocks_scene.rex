/* ------------------------------------------------------------------ */
/* cbd_blocks_scene.rex -- LiDAR building blocks into Power SLAM's    */
/*   scene metres                                                     */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/* Data         : lidar_blocks.rex words (NSW Government LiDAR,       */
/*                CC BY 4.0)                                          */
/*                                                                    */
/* rexx cbd_blocks_scene.rex heights.words blocks.words out.words     */
/*                                                                    */
/* Each block's middle goes from MGA zone 56 to the scene by the       */
/* fitted frame (harbour_frame.cls, good to 0.52 m). Its bearing turns */
/* with the frame: grid north is about 1 degree off the scene's (true) */
/* north here, so a point 10 m along the block is carried across too.  */
/* The LiDAR is GDA2020 and the heights grid GDA94: the same ground    */
/* differs by under 2 m between them, under one 2 m cell; not moved.   */
/* ------------------------------------------------------------------ */
parse arg hFile bFile out .
if out = "" then do
  say "usage: rexx cbd_blocks_scene.rex heights.words blocks.words out.words"
  exit 2
end
numeric digits 16
tile = .HarbourWordsSceneTile~new(.HarbourWordsMGA~new(hFile), 0.9)
fit = .FrameFit~new(tile)
call SysFileDelete out
call lineout out, "-- Building blocks in Power SLAM scene metres (east, north of -33.852, 151.210), true-north bearings."
call lineout out, "-- From" filespec("name", bFile) "by cbd_blocks_scene.rex. Architecture: Tom Dyer. Code: Claude (Opus 5.5)."
call lineout out, "-- LiDAR: NSW Government (DCCEEW Marine LiDAR, August 2018), CC BY 4.0. Heights AHD."
call lineout out, "-- base: ground (AHD); top: base + height (the 90th of 100 roof heights)."
call lineout out, ""
call lineout out, "scene blocks sydney"
n = 0
do while lines(bFile) > 0
  l = linein(bFile)~strip
  if word(l, 1) \== "block" then iterate
  parse var l "block" id "at" e nn "size" len "by" wid "bearing" b "height" h "roof" rf "ground" g "area" a .
  p = fit~scene(e, nn)
  q = fit~scene(e + 10 * RxCalcSin(b, 12, "D"), nn + 10 * RxCalcCos(b, 12, "D"))
  sb = bearingOf(q[1] - p[1], q[2] - p[2]) // 180
  call lineout out, "  block" id "scene" format(p[1], , 1) format(p[2], , 1) "size" len "by" wid "bearing" format(sb, , 1) ,
       "base" g "top" format(g + h, , 1) "height" h "area" a
  n += 1
end
call stream bFile, "c", "close"
call lineout out, "end"
call stream out, "c", "close"
say "wrote" out":" n "blocks"
exit 0

::requires "SlamHarbourWordsScene.cls"
::requires "harbour_frame.cls"
::requires "rxmath" LIBRARY
