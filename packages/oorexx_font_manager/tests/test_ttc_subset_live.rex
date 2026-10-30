parse arg out
if out=="" then out="/tmp/oorexx-font-ttc-subset.otf"
m=.FontManager~new
fc=.FontconfigProvider~new
m~registerProvider(fc)
m~registerTransformer(.PyftsubsetTransformer~new)
n=m~discover
if n<=0 then do; say "SKIP no fonts"; exit 0; end
face=.nil
do f over m~faces
  p=lower(f~path)
  if right(p,4)==".ttc" | right(p,4)==".otc" then do; face=f; leave; end
end
if face==.nil then do; say "SKIP no collection font"; exit 0; end
request=.FontPackageRequest~new(face,out)
request~text="TPS 日本語 Ω"
result=m~package(request)
if \result~success then do; say "FAIL collection subset" face~path face~index result~message; exit 1; end
size=stream(out,"c","query size")
if \datatype(size,"W") | size<=0 then do; say "FAIL empty subset"; exit 2; end
say "PASS collection subset" face~index size face~path
call SysFileDelete out
exit 0
::requires "FontManager.cls"
::requires "FontProviders.cls"
