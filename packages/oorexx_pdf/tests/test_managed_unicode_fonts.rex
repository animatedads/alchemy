parse arg root out helper subsetter tempDir
if root=="" then root=directory()
if out=="" then out="managed-unicode.pdf"
if helper=="" then helper=root||"/vendor/font_manager/tools/fonttools_service.py"
if subsetter=="" then subsetter="pyftsubset"
if tempDir=="" then tempDir="/tmp"
call directory root

m=.FontManager~new
m~registerProvider(.FontconfigProvider~new)
m~registerMetricsProvider(.FontToolsMetricsProvider~new(helper))
m~registerGlyphProvider(.FontToolsGlyphProvider~new(helper))
m~registerTransformer(.PyftsubsetTransformer~new(subsetter))
found=m~discover
if found<=0 then do; say "FAIL no fonts discovered"; exit 1; end
body=m~findForPurpose("PRINT_BODY")
heading=m~findForPurpose("HEADING")
if body==.nil | heading==.nil then do; say "FAIL font purposes"; exit 1; end

report=.PdfFlowReport~new
report~setFontManager(m,tempDir)
report~title="TPS – Unicode Operations Review"
report~subtitle="Résumé / café / Ελληνικά / Русский"
report~headerText="INITECH – TPS CONTROL"
report~footer="NotNotes – Καλημέρα – Привет"
report~addSection("Executive résumé")
report~addParagraph("A café résumé may contain naïve assumptions. Ελληνικά: Καλημέρα. Русский: Привет мир. Currency: € £ ¥.",11,.false,10)
report~addParagraph("WWWW and iiii are intentionally compared through real font metrics; wrapping must therefore be driven by glyph advances rather than character count.",9,.false,10)
headers=.Array~of("TPS","Owner","Résumé","State")
t=.PdfTable~new(headers,.Array~of(70,105,300,75))
t~title="International TPS queue"
do i=1 to 34
  who="André "||i
  note="Café row "||i||" — Καλημέρα — Привет — façade — coöperate — €"||(i*10)||"."
  state="READY"; if i//3=0 then state="RÉVIEW"
  t~addRow(.Array~of("TPS-"||right(i,3,"0"),who,note,state))
end
report~addTable(t)
report~addSection("Conclusion")
report~addParagraph("Unicode extraction, embedded subset fonts and exact metrics are all required for this qualification to pass.",10,.true,0)
bytes=report~render(out)
say "PASS managed unicode" body~face~family heading~face~family bytes out
exit 0
::requires "PdfCore.cls"
