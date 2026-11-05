/* ------------------------------------------------------------------ */
/* streets_to_grid.rex -- gather the street line masks of the lined   */
/*   aerials onto one grid in scene metres                            */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/* Pictures     : NSW Government aerials with street lines (CC BY 4.0) */
/*                                                                    */
/* rexx streets_to_grid.rex out.pgm out.words                          */
/* Each lined picture: its mask (top_rope_lines_diff.rex), where it    */
/* lies on its plain twin, and the plain twin's place in the scene    */
/* (the stitch chain: the Quay aerial on the Planning Portal map,     */
/* each aerial on the one north of it). One aerial place is 1.2694 m. */
/* A grid cell is a street when any line place falls in it.           */
/* ------------------------------------------------------------------ */
parse arg outPgm outWords .
cell = 4; x0 = -1650; x1 = 2000; y0 = -3300; y1 = 920
nc = (x1 - x0) % cell; nr = (y1 - y0) % cell
k = 1.2694
/* mask, lined-on-plain offset, plain's scene x and y at its (0, 0)   */
pics = .array~of("lined1_diff.pgm 60 22 -1082.0 -158.0", ,
                 "lined2_diff.pgm 452 44 -1117.5 -800.3", ,
                 "lined3_diff.pgm 446 26 -1122.6 -1501.0", ,
                 "lined4_diff.pgm 458 0 -1165.8 -2285.5")
grid = .mutableBuffer~new(copies("00"x, nc * nr))
do p over pics
  parse var p f dx dy px py
  s = charin(f, 1, chars(f)); call stream f, "c", "close"
  /* P5 header: magic, width, height, max                              */
  parse var s "P5" "0a"x w h "0a"x "255" "0a"x +0 rest
  hl = pos("255" || "0a"x, s) + 3
  data = substr(s, hl + 1)
  n = 0
  do b = 0 to h - 1
    row = substr(data, b * w + 1, w)
    a = 0
    do forever
      a = pos("ff"x, row, a + 1)
      if a = 0 then leave
      x = px + k * (a - 1 + dx); y = py - k * (b + dy)
      c = trunc((x - x0) / cell); r = trunc((y1 - y) / cell)
      if c < 0 | r < 0 | c >= nc | r >= nr then iterate
      grid~replaceAt("ff"x, r * nc + c + 1, 1); n += 1
    end
  end
  say "  " f":" n "line places placed"
end
call SysFileDelete outPgm
call charout outPgm, "P5" || "0a"x || nc nr || "0a"x || "255" || "0a"x || grid~string
call stream outPgm, "c", "close"
call SysFileDelete outWords
call lineout outWords, "-- Street lines of the NSW Government aerials (CC BY 4.0), on one grid in scene metres."
call lineout outWords, "-- Architecture: Tom Dyer. Code and these words: Claude (Opus 5.5). By streets_to_grid.rex."
call lineout outWords, "-- The picture is" filespec("name", outPgm)": 255 where a street line is."
call lineout outWords, "streets sydney cbd"
call lineout outWords, "  grid scene top left" x0 y1 "cell" cell "across" nc "down" nr "picture" filespec("name", outPgm)
call lineout outWords, "end"
call stream outWords, "c", "close"
say "wrote" outPgm "and" outWords "(" nc "by" nr "cells of" cell "m )"
