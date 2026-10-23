parse arg out
if out=="" then out="/tmp/oorexx-font-subset-test.woff2"
m=.FontManager~new; p=.FontconfigProvider~new; m~registerProvider(p); m~registerTransformer(.PyftsubsetTransformer~new)
n=m~discover
r=m~findForPurpose("WEB_BODY")
if r==.nil then do; say "SKIP no font found"; exit 0; end
req=.FontPackageRequest~new(r~face,out); req~flavor="woff2"; req~text="TPS Report 2026: ABC abc 0123"
result=m~package(req)
if \result~success then do; say "SKIP subset transformer unavailable:" result~message; exit 0; end
if stream(out,"c","query size") <= 0 then do; say "FAIL empty subset"; exit 1; end
say "PASS live subset" result~provider stream(out,"c","query size")
call SysFileDelete out
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
