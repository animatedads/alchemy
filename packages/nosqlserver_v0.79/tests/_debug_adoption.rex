call directory directory("S")
root=.NoSQLServerTestSupport~createBlankDatabase("v078-debug")
ring=.CryptoMacKeyRing~new
ring~addKey("nosql-house","00112233445566778899aabbccddeeff")
sealer=.AlchemyMacSealer~new(ring)
authority=.AlchemyCapabilityAuthority~new(ring)
file=.FileDatabaseEngine~new(root,.nil,sealer,authority)
r=.AlchemyAdoptionVerifier~verify(file,"STANDARD")
say "ok=" r~ok "level=" r~level
say "failures=" r~failures~items
Do f over r~failures
  say "code=" f["code"]
  say "message=" f["message"]
  if f~hasIndex("detail") then say "detail=" f["detail"]
End
bs=r~evidence["base_state"]
say "metadata indexes:" bs["metadata"]~allIndexes
Do k over bs["metadata"]~allIndexes
  say k "=" bs["metadata"][k]
End
integ=r~evidence["inheritance_integrity"]
say "integrity ok=" integ["ok"] "count=" integ["reserved_override_count"]
if integ~hasIndex("violations") then do v over integ["violations"]
  say "violation" v["method"] v["kind"]
end
ignore=.NoSQLServerTestSupport~removeDatabase(root)
::requires "../src/NoSQLServer.cls"
::requires "AlchemyAdoption.cls"
::requires "TestSupport.cls"
