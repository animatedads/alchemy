m=.FontManager~new
p=.FontconfigProvider~new
m~registerProvider(p)
n=m~discover
if n <= 0 then do; say "SKIP fontconfig unavailable"; exit 0; end
q=m~queryForPurpose("CODE")
r=m~find(q)
if r==.nil then do; say "FAIL no CODE match"; exit 1; end
if r~face~path=="" then do; say "FAIL match has no path"; exit 1; end
say "PASS Fontconfig live" r~face~family r~face~style r~face~format
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
