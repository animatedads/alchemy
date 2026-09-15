/* Consumer-neutral Builder -> Server contract fixture. */
::class WireUIServerBuilderFixture public
::method build class
  w=.WireUIDesignWorkspace~new("WireUI.Server.Builder.Contract")

  slots=.table~new; slots["query"]="TEXT"; slots["filter"]="TEXT"
  form=.WireUIVisualComponent~new("FORM","1","FORM",slots,.array~of("surface","field","action"),.array~of("VALIDATION","SEMANTIC_ACTION"))
  semanticRecord=.WireUIVisualComponent~new("SEMANTIC_RECORD","1","SEMANTIC_RECORD",slots,.array~new,.array~of("SEMANTIC_ACTION"))
  list=.WireUIVisualComponent~new("LIST","1","OFFER_LIST")
  do x over .array~of(form,semanticRecord,list); call must w~register(x); end

  query=.WireUISemanticElement~new("QUERY","1","QUERY",.array~of("query","filter"),.array~of("QUERY.SUBMIT"),"PUBLIC")
  results=.WireUISemanticElement~new("RESULTS","1","RESULT_COLLECTION",.array~of("items"),.array~of("RESULT.SELECT"),"PUBLIC")
  account=.WireUISemanticElement~new("ACCOUNT_PANEL","1","ACCOUNT",.array~of("name"),.array~of("ACCOUNT.OPEN"),"AUTHENTICATED")
  do x over .array~of(query,results,account); call must w~register(x); end

  tokens=.table~new; tokens["space.unit"]="8"; tokens["radius.control"]="6"; tokens["density"]="comfortable"
  recipes=.table~new; recipes["query.form"]="surface.primary/form.standard"; recipes["result.list"]="surface.primary/list.cards"
  material=.WireUIMaterialSet~new("WIRE_UI_SERVER_TEST_MATERIAL","1",tokens,recipes); call must w~register(material)

  b=.table~new; b["query"]="query"; b["filter"]="filter"
  humanQuery=.WireUIProjectionDesign~new("QUERY_FORM","1","HUMAN_VISUAL",query~ref,form~ref,"WUI_TEST_QUERY_FORM","QUERY.SUBMIT","query.form","query.form",b)
  agentQuery=.WireUIProjectionDesign~new("QUERY_STATE","1","AI_AGENT_OPTIMISED",query~ref,semanticRecord~ref,"WUI_TEST_QUERY_STATE","QUERY.SUBMIT","","",b)
  humanResults=.WireUIProjectionDesign~new("RESULT_LIST","1","HUMAN_VISUAL",results~ref,list~ref,"WUI_TEST_RESULTS","RESULT.SELECT","result.list","result.list")
  humanAccount=.WireUIProjectionDesign~new("ACCOUNT_PANEL","1","HUMAN_VISUAL",account~ref,list~ref,"WUI_TEST_ACCOUNT","ACCOUNT.OPEN","account.panel","account.panel")
  do x over .array~of(humanQuery,agentQuery,humanResults,humanAccount); call must w~register(x); end

  j=.WireUIJourneyDesign~new("MAIN","1","QUERY")
  call must j~defineState("QUERY",.array~of("QUERY","ACCOUNT_PANEL"),.array~of("RESULTS"),.array~new)
  call must j~defineState("RESULTS",.array~of("RESULTS","ACCOUNT_PANEL"),.array~new,.array~new)
  call must j~allowTransition("QUERY","RESULTS","QUERY.SUBMIT","neutral query submitted")
  call must j~seal; call must w~register(j)

  release=.WireUISiteRelease~new("WIRE_UI_SERVER_NEUTRAL","1")
  do x over .array~of(form,semanticRecord,list,query,results,account,material,humanQuery,agentQuery,humanResults,humanAccount,j); call must release~pin(x~ref); end
  call must release~seal; call must w~register(release)

  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; d["humanSearch"]=humanQuery; d["agentSearch"]=agentQuery; d["material"]=material
  return d

::routine must
  use arg result
  if result~isA(.WireUIDesignResult) then if \result~ok then raise syntax 88.900 array(result~code,result~detail)
  return result
::requires "WireUIBuilderAll.cls"
