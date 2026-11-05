/* ------------------------------------------------------------------ */
/* streets_to_mga.rex -- the street grid (scene metres) on the LiDAR  */
/*   mosaic's MGA cells, so the block builder can cut along streets   */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* rexx streets_to_mga.rex heights.words streets.pgm mosaic.words out.words */
/*   streets.pgm  streets_to_grid.rex's grid: scene top left -1650 920,  */
/*                4 m cells                                            */
/* Each mosaic cell's middle goes to the scene by the fitted frame;    */
/* the cell is street ("s") when its street grid cell is a line.       */
/* ------------------------------------------------------------------ */
parse arg hFile pgm mFile out .
numeric digits 14
tile = .HarbourWordsSceneTile~new(.HarbourWordsMGA~new(hFile), 0.9)
fit = .FrameFit~new(tile)
s = charin(pgm, 1, chars(pgm)); call stream pgm, "c", "close"
parse var s "P5" "0a"x sw sh "0a"x .
data = substr(s, pos("255" || "0a"x, s) + 4)
sx0 = -1650; sy1 = 920; scell = 4
do while lines(mFile) > 0
  l = linein(mFile)~strip
  if word(l, 1) == "grid" then do
    parse var l "south west" x0 y0 "cell" cell "across" nc "up" nr .
    leave
  end
end
call stream mFile, "c", "close"
call SysFileDelete out
call lineout out, "-- Street cells on the LiDAR mosaic grid, from" filespec("name", pgm) "(NSW Government aerial street lines)."
call lineout out, "-- By streets_to_mga.rex, Claude (Opus 5.5); architecture Tom Dyer. s: street, .: not."
call lineout out, "street mask"
call lineout out, "  grid mga 56 gda2020 south west" x0 y0 "cell" cell "across" nc "up" nr
nS = 0
do r = 1 to nr
  ny = y0 + (nr - r + 0.5) * cell
  mb = .mutableBuffer~new
  do c = 1 to nc
    ex = x0 + (c - 0.5) * cell
    p = fit~scene(ex, ny)
    gc = trunc((p[1] - sx0) / scell); gr = trunc((sy1 - p[2]) / scell)
    if gc < 0 | gr < 0 | gc >= sw | gr >= sh then do; mb~append("."); iterate; end
    if substr(data, gr * sw + gc + 1, 1) == "ff"x then do; mb~append("s"); nS += 1; end
    else mb~append(".")
  end
  call lineout out, "  row" mb~string
end
call lineout out, "end"
call stream out, "c", "close"
say "wrote" out":" nS "street cells"
::requires "SlamHarbourWordsScene.cls"
::requires "harbour_frame.cls"
