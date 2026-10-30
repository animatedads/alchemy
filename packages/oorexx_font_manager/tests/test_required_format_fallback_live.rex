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
plan=m~planRunsForPurpose("PRINT_BODY",sample,32,"ja","TrueType")
if \plan~fullyCovered then do; say "FAIL strict TrueType fallback missing" plan~missing~items; exit 1; end
if plan~faces~items<2 then do; say "FAIL strict fallback did not require multiple faces"; exit 2; end
do face over plan~faces
  if translate(face~format)<>"TRUETYPE" then do; say "FAIL non-TrueType face" face~family face~format; exit 3; end
end
say "PASS strict TrueType fallback" plan~faces~items plan~runs~items
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
