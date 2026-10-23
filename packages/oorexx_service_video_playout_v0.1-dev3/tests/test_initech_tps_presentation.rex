/* Real Initech v0.1-dev5 Help Desk, running against a disposable NotNotes DB. */
parse arg dataRoot outFile
if dataRoot='' | outFile='' then do
  say 'USAGE test_initech_tps_presentation.rex DATA_ROOT OUT_FILE'
  exit 2
end
session=.InitechHelpDeskSession~new(dataRoot,'alice')
bridge=.InitechTpsPresentation~new(session)
bad=bridge~prepare('show the TPS Summary Report',outFile)
call eq 'DENIED',bad['STATUS'],'non-personal disclosure denied'
call eq 'PERSONAL_SCOPE_REQUIRED',bad['REASON'],'specific denial'
prior=session~successCount
unsafe=bridge~prepare('log business my TPS report',outFile)
call eq 'DENIED',unsafe['STATUS'],'business mutation cannot be requested as a screen'
call eq 'READ_ONLY_REQUEST_REQUIRED',unsafe['REASON'],'read-only preflight'
call eq prior,session~successCount,'rejected video request did not dispatch'
ready=bridge~prepare('get me a report on my TPS reports',outFile)
call eq 'DISPLAY_READY',ready['STATUS'],'personal TPS scene eligible in fixture'
call eq 'TPS Summary Report',ready['REPORT_NAME'],'report discovered from installed definitions'
call eq 4,ready['ROW_COUNT'],'alice has four TPS reports'
body=charin(outFile,1,chars(outFile))
call contains body,'TPS-2026-102','Alice report present'
call notContains body,'TPS-2026-101','Codex report not leaked'
columns=.Array~new
col=.Directory~new;col['LABEL']='TPS Number';col['BINDING']='TPSNumber';columns~append(col)
col=.Directory~new;col['LABEL']='Cost';col['BINDING']='Cost';columns~append(col)
ignore=session~app~installReportDefinition('TPS Personal Cost Snapshot','TPS Report',columns,.Array~of('Cost'))
next=bridge~prepare('show my TPS Personal Cost Snapshot report',outFile)
call eq 'DISPLAY_READY',next['STATUS'],'runtime installed TPS report recognised'
call eq 'TPS Personal Cost Snapshot',next['REPORT_NAME'],'new report selected without restart'
call eq 4,next['ROW_COUNT'],'dynamic report is owner-filtered'
reviewHelp=session~handle('show me my TPS review reports')
call eq 'SUCCESS',reviewHelp['STATUS'],'live TPS review intention recognised'
call eq 'TPS Report Review Summary',reviewHelp['REPORT_NAME'],'review report identity'
review=bridge~prepare('show me my TPS review reports',outFile)
call eq 'DENIED',review['STATUS'],'long TPS review not silently cropped'
call eq 'REPORT_REQUIRES_PAGINATION',review['REASON'],'pagination required explicitly'
original=bridge~prepare('get me a report on my TPS reports',outFile)
call eq 'DISPLAY_READY',original['STATUS'],'return to the ordinary saved report'
close=session~close
call eq 'SUCCESS',close['RATING'],'help-desk creates real closing TPS review'
say 'PASS: actual helpdesk intention / NotNotes report / Alice-only TPS scene'
say 'PASS: runtime-added report discovered without restarting session'
say 'PASS: end-session TPS process accounted by Help Desk'
exit 0

eq: procedure
  use arg expected,actual,label
  if expected=actual then return
  say 'FAIL:' label 'expected' expected 'actual' actual
  exit 1
contains: procedure
  use arg haystack,needle,label
  if pos(needle,haystack)>0 then return
  say 'FAIL:' label
  exit 1
notContains: procedure
  use arg haystack,needle,label
  if pos(needle,haystack)=0 then return
  say 'FAIL:' label
  exit 1
::requires '../rexx/InitechTpsPresentation.cls'
::requires 'InitechHelpDesk.cls'
