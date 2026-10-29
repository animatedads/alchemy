/* Rasen Falcon Wire semantic editor skeleton — Builder v0.12-dev1 API.
 * No CMS bytes, resource refs, publish rights or hosted runtime are invented.
 * To compile requires the actual Wire Builder and its accepted ooRexx/Alchemy
 * dependency closure; see integrations/CMS_WIRE_BRIDGE.md.
 */
::class RasenFalconWireFixture public
::method build class
  w=.WireUIDesignWorkspace~new('RasenFalcon.Authoring')

  slots=.table~new
  slots['pageId']='TEXT'
  slots['summary']='TEXT'
  slots['editorialState']='TEXT'
  record=.WireUIVisualComponent~new('RF_RECORD','1','SEMANTIC_RECORD',slots,.array~of('surface'),.array~of('SEMANTIC_ACTION'))
  collection=.WireUIVisualComponent~new('RF_COLLECTION','1','OFFER_LIST')
  document=.WireUIVisualComponent~new('RF_DOCUMENT','1','DOCUMENT')
  call rfMust w~register(record)
  call rfMust w~register(collection)
  call rfMust w~register(document)

  overview=.WireUISemanticElement~new('RF_SITE_OVERVIEW','1','SITE_SUMMARY',.array~of('summary'),.array~of('CONTENT.OPEN'),'AUTHENTICATED')
  pages=.WireUISemanticElement~new('RF_PAGE_COLLECTION','1','PAGE_COLLECTION',.array~of('pages'),.array~of('CONTENT.OPEN'),'AUTHENTICATED')
  draft=.WireUISemanticElement~new('RF_PAGE_DRAFT','1','PAGE_DRAFT',.array~of('pageId','editorialState'),.array~of('CONTENT.PROPOSE','CONTENT.REVIEW'),'AUTHENTICATED')
  review=.WireUISemanticElement~new('RF_APPROVAL_DECISION','1','APPROVAL_FACT',.array~of('pageId','editorialState'),.array~of('CONTENT.PUBLISH'),'AUTHENTICATED')
  do e over .array~of(overview,pages,draft,review)
    call rfMust w~register(e)
  end

  tokens=.table~new
  tokens['color.paper']='#f5f1e6'
  tokens['color.ink']='#1e2923'
  tokens['color.wattle']='#b48a35'
  recipes=.table~new
  recipes['rf.overview']='surface.primary/record.standard'
  recipes['rf.collection']='surface.primary/list.rows'
  material=.WireUIMaterialSet~new('RF_STUDIO_MATERIAL','1',tokens,recipes)
  call rfMust w~register(material)

  bindings=.table~new
  bindings['summary']='summary'
  summaryProjection=.WireUIProjectionDesign~new('RF_OVERVIEW_PROJECTION','1','HUMAN_VISUAL',overview~ref,record~ref,'RF_SITE_OVERVIEW','CONTENT.OPEN','rf.overview','rf.overview',bindings)
  listProjection=.WireUIProjectionDesign~new('RF_PAGE_LIST_PROJECTION','1','HUMAN_VISUAL',pages~ref,collection~ref,'RF_PAGE_COLLECTION','CONTENT.OPEN','rf.collection','rf.collection')
  draftProjection=.WireUIProjectionDesign~new('RF_DRAFT_PROJECTION','1','HUMAN_VISUAL',draft~ref,document~ref,'RF_PAGE_DRAFT','CONTENT.PROPOSE','','')
  reviewProjection=.WireUIProjectionDesign~new('RF_REVIEW_PROJECTION','1','HUMAN_VISUAL',review~ref,record~ref,'RF_APPROVAL_DECISION','CONTENT.PUBLISH','','')
  do e over .array~of(summaryProjection,listProjection,draftProjection,reviewProjection)
    call rfMust w~register(e)
  end

  journey=.WireUIJourneyDesign~new('RF_AUTHORING','1','OVERVIEW')
  call rfMust journey~defineState('OVERVIEW',.array~of('RF_SITE_OVERVIEW','RF_PAGE_COLLECTION'),.array~new,.array~new)
  call rfMust journey~defineState('DRAFT',.array~of('RF_PAGE_DRAFT'),.array~new,.array~new)
  call rfMust journey~defineState('REVIEW',.array~of('RF_APPROVAL_DECISION'),.array~new,.array~new)
  call rfMust journey~allowTransition('OVERVIEW','DRAFT','CONTENT.OPEN','open a content draft')
  call rfMust journey~allowTransition('DRAFT','REVIEW','CONTENT.REVIEW','submit a draft for review')
  call rfMust journey~seal
  call rfMust w~register(journey)

  release=.WireUISiteRelease~new('RASEN_FALCON_AUTHORING_SKELETON','1')
  do e over .array~of(record,collection,document,overview,pages,draft,review,material,summaryProjection,listProjection,draftProjection,reviewProjection,journey)
    call rfMust release~pin(e~ref)
  end
  call rfMust release~seal
  call rfMust w~register(release)
  result=.directory~new
  result['workspace']=w
  result['release']=release
  result['journey']=journey
  return result

::routine rfMust
  use arg r
  if r~isA(.WireUIDesignResult) then if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r
::requires 'WireUIBuilderAll.cls'
