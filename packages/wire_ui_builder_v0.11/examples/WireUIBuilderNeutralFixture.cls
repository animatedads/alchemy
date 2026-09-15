/* Consumer-neutral Builder fixture used by core acceptance. */
::class WireUIBuilderNeutralFixture public
::method build class
  w=.WireUIDesignWorkspace~new("WireUIBuilder.Neutral")

  slots=.table~new; slots["query"]="TEXT"; slots["scope"]="TEXT"
  form=.WireUIVisualComponent~new("FORM","1","FORM",slots,.array~of("surface","field","action"),.array~of("VALIDATION","SEMANTIC_ACTION"))
  semanticRecord=.WireUIVisualComponent~new("SEMANTIC_RECORD","1","SEMANTIC_RECORD",slots,.array~new,.array~of("SEMANTIC_ACTION"))
  collection=.WireUIVisualComponent~new("COLLECTION","1","OFFER_LIST")
  do x over .array~of(form,semanticRecord,collection); call must w~register(x); end

  query=.WireUISemanticElement~new("SOURCE_QUERY","1","QUERY",.array~of("query","scope"),.array~of("SOURCE.SEARCH"),"PUBLIC")
  results=.WireUISemanticElement~new("SOURCE_RESULTS","1","SOURCE_COLLECTION",.array~of("items"),.array~of("SOURCE.OPEN"),"PUBLIC")
  privatePanel=.WireUISemanticElement~new("PRIVATE_PANEL","1","PRIVATE_INSPECTOR",.array~of("selection"),.array~of("PRIVATE.OPEN"),"AUTHENTICATED")
  do x over .array~of(query,results,privatePanel); call must w~register(x); end

  tokens=.table~new; tokens["space.unit"]="8"; tokens["radius.control"]="6"; tokens["density"]="comfortable"
  recipes=.table~new; recipes["source.query"]="surface.primary/form.standard"; recipes["source.results"]="surface.primary/list.cards"
  material=.WireUIMaterialSet~new("WIRE_UI_BUILDER_MATERIAL","1",tokens,recipes)
  call must w~register(material)

  b=.table~new; b["query"]="query"; b["scope"]="scope"
  humanSearch=.WireUIProjectionDesign~new("SOURCE_QUERY_FORM","1","HUMAN_VISUAL",query~ref,form~ref,"WUIB_SOURCE_QUERY","SOURCE.SEARCH","source.query","source.query",b)
  agentSearch=.WireUIProjectionDesign~new("SOURCE_QUERY_STATE","1","AI_AGENT_OPTIMISED",query~ref,semanticRecord~ref,"WUIB_SOURCE_QUERY_STATE","SOURCE.SEARCH","","",b)
  humanOffers=.WireUIProjectionDesign~new("SOURCE_RESULTS_LIST","1","HUMAN_VISUAL",results~ref,collection~ref,"WUIB_SOURCE_RESULTS","SOURCE.OPEN","source.results","source.results")
  humanAccount=.WireUIProjectionDesign~new("PRIVATE_PANEL","1","HUMAN_VISUAL",privatePanel~ref,collection~ref,"WUIB_PRIVATE_PANEL","PRIVATE.OPEN","private.panel","private.panel")
  do x over .array~of(humanSearch,agentSearch,humanOffers,humanAccount); call must w~register(x); end

  j=.WireUIJourneyDesign~new("SOURCE_EXPLORER","1","QUERY")
  call must j~defineState("QUERY",.array~of("SOURCE_QUERY","PRIVATE_PANEL"),.array~of("SOURCE_RESULTS"),.array~new)
  call must j~defineState("RESULTS",.array~of("SOURCE_RESULTS","PRIVATE_PANEL"),.array~new,.array~new)
  call must j~allowTransition("QUERY","RESULTS","SOURCE.SEARCH","source query submitted")
  call must j~seal
  call must w~register(j)

  release=.WireUISiteRelease~new("WIRE_UI_BUILDER_NEUTRAL","1")
  do x over .array~of(form,semanticRecord,collection,query,results,privatePanel,material,humanSearch,agentSearch,humanOffers,humanAccount,j); call must release~pin(x~ref); end
  call must release~seal
  call must w~register(release)

  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; d["humanSearch"]=humanSearch; d["agentSearch"]=agentSearch; d["material"]=material
  return d

::routine must
  use arg result
  if result~isA(.WireUIDesignResult) then if \result~ok then raise syntax 88.900 array(result~code,result~detail)
  return result
::requires "WireUIBuilderAll.cls"
