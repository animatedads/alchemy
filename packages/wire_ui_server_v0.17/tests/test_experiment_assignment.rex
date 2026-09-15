/* Runtime experiment assignment: exact compiled projection substitution, never client authority. */
w=.WireUIDesignWorkspace~new("WireUI.RuntimeExperiment")
slots=.table~new; slots["q"]="TEXT"
form=.WireUIVisualComponent~new("FORM","1","FORM",slots)
e=.WireUISemanticElement~new("SEARCH","1","SEARCH",.array~of("q"),.array~of("FLIGHT.SEARCH"),"PUBLIC")
p1=.WireUIProjectionDesign~new("SEARCH_FORM","1","HUMAN_VISUAL",e~ref,form~ref,"SEARCH_FORM","FLIGHT.SEARCH","search.a","search.form")
p2=.WireUIProjectionDesign~new("SEARCH_FORM","2","HUMAN_VISUAL",e~ref,form~ref,"SEARCH_FORM","FLIGHT.SEARCH","search.b","search.form")
do x over .array~of(form,e,p1,p2); call mustDesign w~register(x),"register artifact"; end
exp=.WireUIExperiment~new("SEARCH_LAYOUT","1","SEARCH","SESSION")
call mustDesign exp~addVariant("A",50,p1~ref),"variant A"
call mustDesign exp~addVariant("B",50,p2~ref),"variant B"
call mustDesign exp~seal,"seal experiment"
call mustDesign w~register(exp),"register experiment"
j=.WireUIJourneyDesign~new("BOOKING","1","SEARCH")
call mustDesign j~defineState("SEARCH",.array~of("SEARCH"),.array~new,.array~new),"journey state"
call mustDesign j~seal,"seal journey"
call mustDesign w~register(j),"register journey"
release=.WireUISiteRelease~new("EXPERIMENT_SITE","1")
do x over .array~of(form,e,p1,p2,exp,j); call mustDesign release~pin(x~ref),"pin artifact"; end
call mustDesign release~seal,"seal release"
call mustDesign w~register(release),"register release"
compiler=.WireUICompiler~new
cr=compiler~compile(w,release); call mustDesign cr,"compile"
pkg=cr~value
wire=.table~new; wire["releaseRef"]=pkg~releaseRef~asWire; wire["contentAddress"]=pkg~contentAddress
wire["definitions"]=pkg~definitions; wire["journeyPlans"]=pkg~journeyPlans; wire["materials"]=pkg~materials; wire["experiments"]=pkg~experiments
catalogue=.WireUICompiledCatalogue~new(wire)
view=.WireUIView~new("EXP.RUNTIME","root"); projection=.WireUIProjection~new
app=.WireUIApplication~new("exp-app","session-42","ap-exp",view,projection)
call must app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL),"bind"
/* Unassigned experiment must not silently choose a variant: both exact definitions are staged. */
call expect activeHas(app,"SEARCH_FORM@1"),"unassigned release retains compiled v1"
call expect activeHas(app,"SEARCH_FORM@2"),"unassigned release retains compiled v2"
r=app~assignExperiment("SEARCH_LAYOUT","B","session-42"); call must r,"assign B"
a=app~experimentAssignment("SEARCH_LAYOUT")
call expect a~variantId="B","assignment recorded"
call expect a~definitionKey="SEARCH_FORM@2","variant resolves exact projection definition"
call expect a~siteReleaseContentAddress=release~contentAddress,"assignment bound to exact release"
call expect activeHas(app,"SEARCH_FORM@2"),"assigned exact definition active"
call expect \activeHas(app,"SEARCH_FORM@1"),"non-assigned variant not active"
plan=app~journeyPlanMessage~value
call expect plan~hasIndex("experimentAssignments"),"journey wire carries assignment provenance"
call expect plan["experimentAssignments"]["SEARCH_LAYOUT"]["variantId"]="B","wire assignment exact"
call expect \plan["experimentAssignments"]["SEARCH_LAYOUT"]~hasIndex("subjectRef"),"private assignment subject not emitted"
snap=app~snapshot
call expect snap["experimentAssignments"]["SEARCH_LAYOUT"]["definitionKey"]="SEARCH_FORM@2","snapshot carries assignment provenance"
r=app~assignExperiment("SEARCH_LAYOUT","NOPE","session-42")
call expect \r~ok & r~code="EXPERIMENT_VARIANT_NOT_FOUND","unknown variant rejected"
say "PASS runtime compiled experiment assignment"
exit 0

activeHas: procedure
  use arg app,key
  do sub over app~activeSubscriptions
    if sub~containsDefinition(key) then return .true
  end
  return .false
mustDesign: procedure
  use arg r,l
  if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
  return
must: procedure
  use arg r,l
  if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
  return
expect: procedure
  use arg c,l
  if \c then do; say "FAIL" l; exit 1; end
  say "ok" l
  return
::requires "WireUIBuilderAll.cls"
::requires "WireUIAll.cls"
