b=.WireUIBuilderNeutralFixture~build
c=.WireUICompiler~new
cr=c~compile(b["workspace"],b["release"])
if \cr~ok then do; say "FAIL compile" cr~code; exit 1; end
scenario=.WireUIPreviewScenario~new("s","1","u",.false,"HUMAN_VISUAL","QUERY",b["release"]~ref)
objects=.array~of(b["workspace"],b["release"],b["journey"],b["humanSearch"],b["material"],c,cr~value,scenario)
do o over objects
  r=.AlchemyAdoptionVerifier~verify(o,"STANDARD")
  if \r~ok then do
    say "FAIL adoption" o~class~id r~failures~items
    do f over r~failures; say f["code"] f["message"]; end
    exit 1
  end
end
say "PASS AlchemyObject STANDARD adoption" objects~items
exit 0
::requires "WireUIBuilderNeutralFixture.cls"
::requires "AlchemyAdoption.cls"
