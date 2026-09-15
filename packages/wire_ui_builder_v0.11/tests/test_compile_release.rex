call test
say "PASS test_compile_release"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build
  c=.WireUICompiler~new
  r=c~compile(b["workspace"],b["release"])
  call assert r~ok,"compile"
  p=r~value
  call assert p~definitions~items=4,"four exact projections"
  call assert p~journeyPlans~items=2,"journey compiled for human and agent profiles"
  found=.false
  do d over p~definitions
    if d["definitionKey"]="WUIB_SOURCE_QUERY@1" then found=.true
  end
  call assert found,"version-qualified definition key"
  call assert p~releaseRef~contentAddress=b["release"]~contentAddress,"release graph pinned"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
