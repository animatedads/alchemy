/*
 * Initech TPS information-scene admission. Read-only video projection, not
 * an authorisation service. The Help Desk must resolve the user's intention
 * and produce an actual SUCCESS/RUN_REPORT sceneResult before anything is drawn.
 *
 * Dev2 deliberately limits disclosure to explicit "my ..." TPS requests;
 * still requires an externally authenticated and authorised session before
 * production use. Nothing is cached; NotNotes report discovery is live.
 */
::class InitechTpsPresentation public
::method init
  expose session
  use strict arg sessionArg
  session=sessionArg

::method prepare
  expose session
  use strict arg request, textPath
  sceneResult=.Directory~new
  sceneResult['STATUS']='DENIED'
  sceneResult['REASON']='NO_DISPLAY_GRANT'
  sceneResult['SCENE']='NONE'
  sceneResult['CONTRACT']='initech.video.presentation/0.1-dev2'
  sceneResult['SCOPE']='FIXTURE_REVIEW_ONLY'
  upper=translate(' '||request~strip||' ')
  if pos(' MY ', upper)=0 then do
    sceneResult['REASON']='PERSONAL_SCOPE_REQUIRED'
    return sceneResult
  end
  if pos('TPS',upper)=0 | pos('REPORT',upper)=0 then do
    sceneResult['REASON']='TPS_REPORT_REQUIRED'
    return sceneResult
  end
  if textPath~strip='' then do
    sceneResult['REASON']='OUTPUT_REQUIRED'
    return sceneResult
  end
  /* Read-only preflight occurs BEFORE Help Desk dispatch. A malformed
   * presentation query may not create a Business Log, submit, approve, etc. */
  verb=upper~strip~word(1)
  admittedVerb=.false
  do readVerb over .Array~of('GET','SHOW','RUN','LIST','DISPLAY')
    if verb=readVerb then do
      admittedVerb=.true
      leave
    end
  end
  if \admittedVerb then do
    sceneResult['REASON']='READ_ONLY_REQUEST_REQUIRED'
    return sceneResult
  end
  do forbidden over .Array~of('LOG BUSINESS','CREATE','SUBMIT','APPROVE','REJECT','DELETE','UPDATE','AMEND','PAY','TRANSFER')
    if pos(forbidden,upper)>0 then do
      sceneResult['REASON']='READ_ONLY_REQUEST_REQUIRED'
      return sceneResult
    end
  end
  /* Execute exactly once through the real current Help Desk. */
  help=session~handle(request)
  if help['STATUS'] \= 'SUCCESS' then do
    sceneResult['REASON']='INTENTION_NOT_SUCCESS'
    sceneResult['HELP_STATUS']=help['STATUS']
    return sceneResult
  end
  if help['INTENTION'] \= 'RUN_REPORT' then do
    sceneResult['REASON']='NOT_SAVED_REPORT_RESULT'
    return sceneResult
  end
  name=help['REPORT_NAME']
  /* Recheck the current semantic report description. A snapshot of meanings
   * retained by the video worker is never allowed to decide business scope. */
  application=session~app~semanticApplicationProjection
  if application['CONTRACT'] \= 'MININOTES.SEMANTIC_APPLICATION/1' then do
    sceneResult['REASON']='UNKNOWN_NOTNOTES_APPLICATION_CONTRACT'
    return sceneResult
  end
  found=.false
  do report over application['REPORTS']
    if report['NAME'] \= name then iterate
    source=report['SOURCE_FORM']
    if source='TPS Report' | source='TPS Report Review' then found=.true
    leave
  end
  if \found then do
    sceneResult['REASON']='REPORT_SOURCE_NOT_ADMITTED'
    return sceneResult
  end
  if help['COUNT']>12 | help['COUNT']<0 then do
    sceneResult['REASON']='REPORT_EXCEEDS_CARD_BOUND'
    return sceneResult
  end
  /* No implicit truncation of a real report. Explicitly reject overflow. */
  if help['TEXT']~length>3500 then do
    sceneResult['REASON']='REPORT_TEXT_EXCEEDS_CARD_BOUND'
    return sceneResult
  end
  /* The present 720p fixed-size card is single-page. Reject content that
   * would be cropped rather than silently hiding authorised report rows. */
  lines=0
  pending=help['TEXT']
  do while pending<>''
    eol=pos('0a'x,pending)
    if eol=0 then do
      current=pending
      pending=''
    end
    else do
      current=left(pending,eol-1)
      pending=substr(pending,eol+1)
    end
    lines+=1
    if current~length>74 | lines>9 then do
      sceneResult['REASON']='REPORT_REQUIRES_PAGINATION'
      return sceneResult
    end
  end
  if stream(textPath,'C','OPEN WRITE REPLACE')\='READY:' then do
    sceneResult['REASON']='OUTPUT_OPEN_FAILED'
    return sceneResult
  end
  ignore=charout(textPath,help['TEXT'])
  ignore=stream(textPath,'C','CLOSE')
  sceneResult['STATUS']='DISPLAY_READY'
  sceneResult['REASON']='FIXTURE_SCOPE_ONLY'
  sceneResult['SCENE']='TPS_REPORT'
  sceneResult['REPORT_NAME']=name
  sceneResult['ROW_COUNT']=help['COUNT']
  sceneResult['TEXT_FILE']=textPath
  return sceneResult
