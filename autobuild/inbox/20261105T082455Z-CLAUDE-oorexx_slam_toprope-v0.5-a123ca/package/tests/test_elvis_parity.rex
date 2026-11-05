#!/usr/bin/env rexx
/* test_elvis_parity.rex -- Top Rope's height grid reads the harbour      */
/* words the same as the qualified ELVIS provider does.                    */
/* Fixture: grid_sample_120.psv from examples/tombstone_sydney_elvis_      */
/* terrain_v0.36 (120 exact cells, 20 NoData), made by ChatGPT GPT-6 for   */
/* HarbourHeightWords.cls. At a grid point, Top Rope's bilinear height     */
/* must be exactly the source word, and NoData must come back as nothing.  */
/* Architecture: Tom Dyer. This test: Claude (Opus 5.5).                   */
  parse source . . me
  root = filespec('L', me)'..'
  g = .HeightGrid~new(root'/examples/harbour/harbour_heights.words', 'ELVIS')
  e0 = 330586.9; n0 = 6259261.5; step = 50
  s = .stream~new(root'/tests/fixtures/elvis_grid_sample_120.psv')~~open('read')
  hdr = s~linein                                  /* header */
  tests = 0; fails = 0; nodata = 0
  do while s~lines > 0
    parse value s~linein with row '|' col '|' word .
    if row = '' then iterate
    tests = tests + 1
    h = g~heightXY(e0 + (col - 1) * step, n0 - (row - 1) * step)
    if word == '-' then do
      nodata = nodata + 1
      if h \== '' then do; say 'FAIL' row col 'NoData came back as' h; fails = fails + 1; end
      iterate
    end
    if h == '' then do; say 'FAIL' row col 'no height, source' word; fails = fails + 1; iterate; end
    if abs(h - word) > 0.0001 then do; say 'FAIL' row col 'height' h 'source' word; fails = fails + 1; end
  end
  s~close
  say tests - fails 'of' tests 'cells match the ELVIS provider fixture ('nodata 'NoData)'
  exit fails \= 0
::requires 'sight_line.cls'
