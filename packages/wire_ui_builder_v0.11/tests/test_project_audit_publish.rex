call test
say "PASS test_project_audit_publish"
exit 0

test:
  p=.WireUIBuilderProject~new("AUDIT.TEST","Audit Test")
  spec=.table~new; spec["publishVersion"]="1"; spec["primitive"]="PANEL"
  payload=.table~new; payload["artifactId"]="AUDIT_PANEL"; payload["spec"]=spec
  evidence=.array~of("source:src/WireUIBuilderProject.cls")
  op=.WireUIDesignOperation~new("audit-op-1","DESIGN.COMPONENT.DRAFT",0,.nil,payload,"AI:SELF_TEST","audit boundary regression",evidence)
  call assert op~contentAddress~left(7)="wuid01-","draft operation uses fast deterministic address"
  call assert op~auditDigest~left(7)="sha512-","operation audit evidence strongly sealed on demand"
  r=p~applyOperation(op); call assert r~ok,"draft operation accepted"
  pw=p~asWire
  call assert pw["operations"]~items=1,"project persists operation ledger"
  call assert \pw["operations"][1]~hasIndex("auditDigest"),"autosave/project wire does not force expensive audit digest"
  pr=p~publish("AUDIT_SITE","1"); call assert pr~ok,"project published"
  release=pr~value["release"]
  call assert release~ref~contentAddress~left(7)="sha512-","published release graph strongly sealed"
  rw=release~asWire; md=rw["metadata"]
  call assert md["builderOperationLedgerFingerprint"]~left(7)="ledger-","release records deterministic operation ledger fingerprint"
  aw=op~asWire; call assert aw["auditDigest"]=op~auditDigest,"explicit operation wire carries strong audit digest"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
