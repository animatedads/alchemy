parse source . . here
pkg=filespec('location',here)
catalog=.McpProjectComponentCatalog~fromJsonFile(pkg||'../catalog/components.json')
service=.McpProjectWireService~new(catalog,.McpProjectMemoryJournal~new)

all=.directory~new
r=service~dispatch('PROJECT.COMPONENTS.LIST',all,'llm:test')
call assert r~ok, 'combined catalog lists'
call assert r~value['count']=135, 'combined catalog contains 135 artifact entries'
call assert r~value['uniqueComponentCount']=129, 'combined catalog contains 129 unique canonical component ids'
call assert r~value['runtimeEntryCount']=82, 'runtime artifact entries preserved'
call assert r~value['sphereEntryCount']=53, 'sphere artifact entries projected'

onlySpheres=.directory~new; onlySpheres['componentKind']='sphere'
r=service~dispatch('PROJECT.COMPONENTS.LIST',onlySpheres,'llm:test')
call assert r~ok & r~value['count']=53 & r~value['sphereEntryCount']=53, 'sphere kind filter lists sphere components only'

call assert catalog~resolveId('oorexx_llm_pitfalls')='sphere:oorexx-llm-pitfalls', 'filename alias resolves to canonical sphere component'
call assert catalog~resolveId('oorexx-llm-pitfalls')='sphere:oorexx-llm-pitfalls', 'gopher id alias resolves to canonical sphere component'
call assert catalog~resolveId('sphere:oorexx_llm_pitfalls')='sphere:oorexx-llm-pitfalls', 'namespaced underscore alias resolves'
call assert catalog~resolveId('civicport')='civicport', 'runtime exact id wins over colliding sphere alias'
call assert catalog~resolveId('sphere:civicport')='sphere:civicport', 'colliding sphere remains independently addressable'

claim=.directory~new; claim['componentId']='oorexx_llm_pitfalls'
r=service~dispatch('PROJECT.OWNERSHIP.CLAIM',claim,'llm:claude')
call assert r~ok & r~value['componentId']~string='sphere:oorexx-llm-pitfalls', 'sphere can be owned independently'

request=.directory~new; request['componentId']='oorexx_llm_pitfalls'; request['body']='Maintain current model/access-point evidence.'
r=service~dispatch('PROJECT.REQUEST.CREATE',request,'architect')
call assert r~ok & r~value['componentId']~string='sphere:oorexx-llm-pitfalls', 'sphere can receive project request'
call assert r~value['recipientId']~string='llm:claude', 'sphere request routes to active sphere owner'

release=.directory~new; release['componentId']='sphere:oorexx-llm-pitfalls'; release['reason']='qualification complete'
r=service~dispatch('PROJECT.OWNERSHIP.RELEASE',release,'llm:claude')
call assert r~ok & r~code='OWNERSHIP_RELEASED', 'sphere ownership release works'

bad=.directory~new; bad['componentKind']='banana'
r=service~dispatch('PROJECT.COMPONENTS.LIST',bad,'llm:test')
call assert \r~ok & r~code='INVALID_ARGUMENT', 'unknown component kind rejected'

say 'PASS test_sphere_components'
exit 0

assert: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return

::requires 'McpProjectService.cls'
