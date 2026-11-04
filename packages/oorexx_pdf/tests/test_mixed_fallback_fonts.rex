parse arg root out helper subsetter tempDir
if root=="" then root=directory()
if out=="" then out="mixed-fallback.pdf"
if helper=="" then helper=root||"/vendor/font_manager/tools/fonttools_service.py"
if subsetter=="" then subsetter="pyftsubset"
if tempDir=="" then tempDir="/tmp"
call directory root
m=.FontManager~new
fc=.FontconfigProvider~new
m~registerProvider(fc)
m~registerCoverageProvider(fc)
m~registerMetricsProvider(.FontToolsMetricsProvider~new(helper))
m~registerGlyphProvider(.FontToolsGlyphProvider~new(helper))
m~registerTransformer(.PyftsubsetTransformer~new(subsetter))
found=m~discover
if found<=0 then do; say "FAIL no fonts discovered"; exit 1; end
sample="TPS café — 日本語 — Ελληνικά — Русский — Ω ∑"
plan=m~planRunsForPurpose("PRINT_BODY",sample,24,"ja")
if \plan~fullyCovered then do; say "FAIL fallback plan missing" plan~missing~items; exit 2; end
if plan~faces~items<2 then do; say "FAIL expected fallback face" plan~faces~items; exit 3; end
report=.PdfFlowReport~new
report~setFontManager(m,tempDir)
report~title="TPS 日本語 – Mixed-script review"
report~subtitle="café / Ελληνικά / Русский / 日本語"
report~headerText="INITECH – 国際 TPS CONTROL"
report~footer="NotNotes – Καλημέρα – Привет – 日本語"
report~addSection("Executive 日本語 summary")
report~addParagraph("Mixed-script fallback: "||sample||". Each character must select a FontManager-proven face without glyph-zero substitution.",11,.false,10)
headers=.Array~of("TPS","Owner","Description","State")
t=.PdfTable~new(headers,.Array~of(70,100,310,70))
t~title="International TPS queue – 日本語"
do i=1 to 4
  owner="André "||i
  note="Row "||i||" — café — 日本語 — Καλημέρα — Привет — Ω ∑ — €"||(i*7)||"."
  state="READY"; if i//4=0 then state="RÉVIEW"
  t~addRow(.Array~of("TPS-"||right(i,3,"0"),owner,note,state))
end
report~addTable(t)
report~addSection("結論 / Conclusion")
report~addParagraph("Fallback faces must remain embedded subsets with ToUnicode extraction.",10,.true,0)
bytes=report~render(out)
say "PASS mixed fallback" plan~faces~items plan~runs~items bytes out
exit 0
::requires "PdfCore.cls"
