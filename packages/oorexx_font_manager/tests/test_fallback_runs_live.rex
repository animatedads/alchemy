parse arg helper
if helper=="" then helper="fonttools_service.py"
m=.FontManager~new
fc=.FontconfigProvider~new
m~registerProvider(fc)
m~registerCoverageProvider(fc)
m~registerGlyphProvider(.FontToolsGlyphProvider~new(helper))
n=m~discover
if n<=0 then do; say "SKIP no fonts"; exit 0; end
sample="TPS café — 日本語 — Ω ∑"
plan=m~planRunsForPurpose("PRINT_BODY",sample,24,"ja")
if \plan~fullyCovered then do
  say "FAIL missing glyphs" plan~missing~items
  exit 1
end
if plan~runs~items < 2 then do
  say "FAIL fallback did not create multiple runs"
  exit 1
end
hasJapanese=.false
hasMath=.false
do run over plan~runs
  if pos('e697a5'x,run~text)>0 then hasJapanese=.true
  if pos('e28891'x,run~text)>0 then hasMath=.true
end
if \hasJapanese then do; say "FAIL Japanese run missing"; exit 1; end
if \hasMath then do; say "FAIL math run missing"; exit 1; end
say "PASS fallback runs" plan~faces~items plan~runs~items
do run over plan~runs
  say "RUN" run~face~family "bytes="length(run~text)
end
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
