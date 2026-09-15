call test
say "PASS test_source_catalogue_v031"
exit 0

test:
  path="/tmp/wuib-source-v031-"random(100000,999999)".cls"
  s=.stream~new(path); r=s~open("WRITE REPLACE"); call assert r="READY:" | r="READY","temp source opened"
  s~lineOut("::options digits 30")
  s~lineOut("::class Sample public")
  s~lineOut('::constant API_VERSION "1"')
  s~lineOut("::attribute value get")
  s~lineOut("::method ping")
  s~lineOut('  return "pong"')
  s~lineOut('::requires "Other.cls"')
  s~close
  c=.WireUISourceCatalogue~new("TEST")
  r=c~addFile(path,"builder/Sample.cls"); call assert r~ok,"source added"
  f=r~value
  call assert f~constants~items=1,"constant surface captured"
  call assert f~constants[1]["name"]="API_VERSION","constant identity"
  call assert f~packageOptions~items=1,"package options captured"
  call assert f~packageOptions[1]="digits 30","package option value"
  call assert f~attributes~items=1,"attribute still captured"
  call assert f~requires~items=1,"requires still captured"
  w=f~asWire
  call assert w["id"]="builder/Sample.cls","wire identity uses relocation-stable logical path"
  call assert w["sourceId"]="Sample.cls","display sourceId retained separately"
  call assert w["constants"]~items=1,"constant surface on wire"
  call assert w["packageOptions"]~items=1,"package options on wire"
  call assert c~constantCount=1,"catalogue constant count"
  call assert c~attributeCount=1,"catalogue attribute count"
  call assert c~packageOptionCount=1,"catalogue option count"
  call SysFileDelete path
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUISourceCatalogue.cls"
