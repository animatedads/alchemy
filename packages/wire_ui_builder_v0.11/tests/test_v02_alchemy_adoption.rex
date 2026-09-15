b=.WireUIBuilderNeutralFixture~build
w=b["workspace"]
p=.table~new; p["newVersion"]="2"; p["componentRef"]=w~artifact("COMPONENT","COLLECTION","1")~ref
op=.WireUIDesignOperation~new("adopt-op","DESIGN.PROJECTION.SET_COMPONENT",0,b["humanSearch"]~ref,p,"AI")
r=w~applyOperation(op); if \r~ok then do; say "FAIL operation" r~code; exit 1; end
lin=w~lineageFor(r~value~ref)
scenario=.WireUIPreviewScenario~new("s","1","u",.false,"HUMAN_VISUAL","QUERY",b["release"]~ref)
matrix=.WireUIPreviewMatrix~new("m","1",b["release"]~ref); matrix~addScenario(scenario); matrix~seal
renderer=.WireUIArtifactRef~new("RENDERER","ALCHEMY_WIRE_UI_JS","0.4-dev1","sha512-build")
ro=.WireUIRenderObservation~new("ro","1",b["release"]~ref,scenario~ref,renderer,"manifest",.table~new)
search=w~artifact("ELEMENT","SOURCE_QUERY","1"); form=w~artifact("COMPONENT","FORM","1")
eo=.WireUIRenderElementObservation~new("ri",search~ref,"semantic/ri",b["humanSearch"]~ref,form~ref)
ro~addElement(eo); ro~seal
assessment=.WireUIDesignAssessment~new("a","1","VISUAL","LOW",0.5,"review",ro~ref)
proposal=.WireUIDesignProposal~new("p","1",assessment~ref,.array~of(op~ref))
adapter=.WireUIBuilderActionAdapter~new(w)
objects=.array~of(op,lin,matrix,ro,eo,assessment,proposal,adapter)
do o over objects
  vr=.AlchemyAdoptionVerifier~verify(o,"STANDARD")
  if \vr~ok then do
    say "FAIL adoption" o~class~id vr~failures~items
    do f over vr~failures; say f["code"] f["message"]; end
    exit 1
  end
end
say "PASS v0.2 AlchemyObject STANDARD adoption" objects~items
exit 0
::requires "WireUIBuilderNeutralFixture.cls"
::requires "AlchemyAdoption.cls"
