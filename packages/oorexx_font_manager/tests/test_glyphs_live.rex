parse arg helper
if helper=="" then helper="fonttools_service.py"
m=.FontManager~new
m~registerProvider(.FontconfigProvider~new)
m~registerGlyphProvider(.FontToolsGlyphProvider~new(helper))
n=m~discover
r=m~findForPurpose("BODY")
if r==.nil then do; say "FAIL no font"; exit 1; end
plan=m~glyphPlan(r~face,"TPS café Ω Ж")
if plan~unitsPerEm <= 0 then do; say "FAIL upm"; exit 1; end
if plan~glyphs~items < 5 then do; say "FAIL glyphs" plan~glyphs~items; exit 1; end
omega=plan~glyphForBytes('cea9'x)
if omega==.nil then do; say "FAIL omega"; exit 1; end
if omega~unicodeHex \== "03A9" then do; say "FAIL omega map" omega~unicodeHex; exit 1; end
say "PASS live glyph plan" r~face~family plan~unitsPerEm plan~glyphs~items
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
