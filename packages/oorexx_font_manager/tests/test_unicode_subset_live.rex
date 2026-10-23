parse arg helper subsetter out
if helper=="" then helper="fonttools_service.py"
if subsetter=="" then subsetter="pyftsubset"
if out=="" then out="/tmp/oorexx-font-unicode-subset.ttf"
m=.FontManager~new
m~registerProvider(.FontconfigProvider~new)
m~registerTransformer(.PyftsubsetTransformer~new(subsetter))
m~registerGlyphProvider(.FontToolsGlyphProvider~new(helper))
n=m~discover
r=m~findForPurpose("PRINT_BODY")
if r==.nil then do; say "FAIL no PRINT_BODY font"; exit 1; end
sample="naïve façade coöperate — € £ ¥ Привет мир Καλημέρα"
q=.FontPackageRequest~new(r~face,out); q~text=sample; q~subset=.true
result=m~package(q)
if \result~success then do; say "FAIL package" result~message; exit 1; end
sub=.FontFace~new(r~face~family,out,r~face~style,r~face~fullName,r~face~postscriptName,r~face~weight,r~face~slant,r~face~spacing,.true,"TrueType","TEST")
plan=m~glyphPlan(sub,sample)
do b over .Array~of('c3af'x,'c3a7'x,'c3b6'x,'e28094'x,'e282ac'x,'d0bc'x)
  g=plan~glyphForBytes(b)
  if g==.nil | g~glyphId==0 then do; say "FAIL subset glyph" c2x(b); call SysFileDelete out; exit 1; end
end
say "PASS unicode subset" r~face~family plan~glyphs~items
call SysFileDelete out
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
