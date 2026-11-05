/* ------------------------------------------------------------------ */
/* mosaic_pgm.rex -- the LiDAR mosaic's tops as a grey picture         */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx mosaic_pgm.rex mosaic.words out.pgm [metres-per-grey]         */
/*                                                                    */
/* One pixel per cell, north up. Grey = top AHD / step (default 1.2,  */
/* so 300 m is 250), 0 where the cell has no return. A diagnostic.    */
/* ------------------------------------------------------------------ */
parse arg mos out step .
if out = "" then do
  say "usage: rexx mosaic_pgm.rex mosaic.words out.pgm [metres-per-grey]"
  exit 2
end
if step = "" then step = 1.2
rows = .array~new
do while lines(mos) > 0
  l = linein(mos)~strip
  w1 = word(l, 1)
  if w1 == "grid" then parse var l "across" nc "up" nr .
  else if w1 == "top" then rows~append(subword(l, 2))
end
call stream mos, "c", "close"
mb = .mutableBuffer~new
do r = 1 to nr
  tr = rows[r]
  do c = 1 to nc
    v = word(tr, c)
    g = 0
    if datatype(v, "N") then g = max(1, min(255, trunc(v / step)))
    mb~append(d2c(g))
  end
end
call SysFileDelete out
call charout out, "P5" || "0a"x || nc nr || "0a"x || "255" || "0a"x
call charout out, mb~string
call stream out, "c", "close"
say "wrote" out":" nc "by" nr
exit 0
