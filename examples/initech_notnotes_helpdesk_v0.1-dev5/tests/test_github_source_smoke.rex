/* Fresh-storage source-only Help Desk qualification. No retained TPS fixture. */
store = value('TEST_DATA_ROOT',,'ENVIRONMENT')
if store = '' then raise syntax 93.900 array('TEST_DATA_ROOT required')
app = .MiniNotesApp~new(store)

fields = .Array~new
fields~append(spec('TPSNumber', 'TPS Number', 'IDENTIFIER'))
fields~append(spec('User','User','USER_REFERENCE'))
fields~append(spec('Cost','Cost','MONEY'))
call assertTrue app~installUserFormat('TPS Report', fields) \== .nil, 'TPS format installation'

reviews = .Array~new
r = spec('TheTPSReport','The TPS Report','DOCUMENT_REFERENCE')
r['REF_TARGET'] = 'TPS Report'
reviews~append(r)
reviews~append(spec('TheReview','The Review','TEXT'))
reviews~append(spec('TheRating','The Rating','TEXT'))
call assertTrue app~installUserFormat('TPS Report Review', reviews) \== .nil, 'TPS Review format installation'

/* Prove the next process loads the persisted format definitions. */
session = .InitechHelpDeskSession~new(store, 'alice')
cat = session~discover
call assertEquals 'MININOTES.SEMANTIC_APPLICATION/1', cat['CONTRACT'], 'semantic contract'
call assertTrue cat['FORMATS']~items >= 3, 'fresh TPS and business log formats'
call assertTrue cat['SPECIALISTS']~items > 0, 'fresh specialist discovery'

health = session~handle('show NotNotes health and metrics')
call assertEquals 'SUCCESS', health['STATUS'], 'instrumentation request'
call assertEquals 'INSTRUMENTATION', health['AUTHORITY'], 'specialist authority'

logged = session~handle('log business source-only check')
call assertEquals 'SUCCESS', logged['STATUS'], 'business log request'
call assertContains logged['DOCUMENT_KEY'], 'BL-', 'document key'

close = session~close
call assertEquals 'SUCCESS', close['RATING'], 'session TPS rating'
call assertContains close['TPS_KEY'],'TR-','TPS report written'
call assertContains close['REVIEW_KEY'],'TRR-','TPS review written'

session2 = .InitechHelpDeskSession~new(store, 'alice')
history = session2~handle('show my successful Help Desk TPS processes')
call assertEquals 'SUCCESS',history['STATUS'],'reopen support history'
call assertContains history['TEXT'],close['TPS_NUMBER'],'durable TPS history'

failed = .InitechHelpDeskSession~new(store, 'bob')
unknown = failed~handle('please recalibrate the quantum stapler')
call assertEquals 'UNKNOWN',unknown['STATUS'],'unsupported request is unknown'
failedClose = failed~close
call assertEquals 'FAILURE',failedClose['RATING'],'failure persisted as TPS review'
reloadedFailed = .InitechHelpDeskSession~new(store, 'bob')
failedHistory = reloadedFailed~handle('show my failed Help Desk TPS processes')
call assertEquals 'SUCCESS',failedHistory['STATUS'],'failure history survives restart'
call assertContains failedHistory['TEXT'],failedClose['TPS_NUMBER'],'durable failed TPS history'

say 'PASS source-only Initech NotNotes Help Desk: live discovery, instrumentation, business write, durable TPS success/failure'
exit 0

::routine spec
  use strict arg field,label,type
  d = .Directory~new
  d['NAME'] = field; d['LABEL'] = label; d['TYPE'] = type
  return d
::routine assertEquals
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 93.900 array(label || ' expected=' || expected || ' actual=' || actual)
  return
::routine assertTrue
  use strict arg condition,label
  if \condition then raise syntax 93.900 array(label)
  return
::routine assertContains
  use strict arg haystack,needle,label
  if pos(needle,haystack) = 0 then raise syntax 93.900 array(label || ' missing=' || needle)
  return
::requires 'InitechHelpDesk.cls'