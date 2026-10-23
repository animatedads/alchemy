parse arg helper
if helper=="" then helper="fonttools_service.py"
m=.FontManager~new; p=.FontconfigProvider~new; m~registerProvider(p); n=m~discover
if n<=0 then do; say "SKIP no fonts"; exit 0; end
m~registerMetricsProvider(.FontToolsMetricsProvider~new(helper))
r=m~findForPurpose("BODY")
if r==.nil then do; say "FAIL no BODY font"; exit 1; end
wide=m~measure(r~face,"WWWW",12)
narrow=m~measure(r~face,"iiii",12)
if wide~provider \== "FONTTOOLS" then do; say "FAIL metrics provider" wide~provider; exit 1; end
if wide~width <= narrow~width then do; say "FAIL metrics width" wide~width narrow~width; exit 1; end
if wide~ascender <= 0 then do; say "FAIL ascender"; exit 1; end
say "PASS live metrics" r~face~family wide~width narrow~width
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
