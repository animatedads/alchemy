/* Mail qualification fixture: conventional Wire-style semantic activation and a
   deliberately different spatial interaction must enter the same action and
   ordinary ooRexx behaviour, producing the same authoritative semantic trace. */
call addPath

mail=.MailQualificationBehaviour~new
app=.Wire3DSpaceApp~new('mailclient','wire-app://mail-hub','1.0')
message=.directory~new
message['identity']='INBOX|77|1042'
message['subject']='Quarterly operations'
app~expose('selectedMessage',message,'READ')
spatialMessage=app~project('selectedMessage','mail-message-1042', -
    .Wire3DRepresentation~new('correspondence','Quarterly operations','application'))
app~bind('message.open',mail,'openMessage','USE')
app~mapInteraction('spatial.enter-correspondence','message.open')
app~entryPoint('inbox','selectedMessage','message.open')

/* Conventional projection: a list/pane renderer has already translated its
   click/tap into the semantic action. */
mail~reset
conventionalPayload=.directory~new
conventionalPayload['requestedView']='MESSAGE'
r1=app~activate('message.open',message,.nil,conventionalPayload)
trace1=mail~trace
call assert r1='OPENED','conventional semantic activation reaches ordinary behaviour'

/* Spatial projection: walking/entering the correspondence is a different
   interaction vocabulary, mapped back to the exact same semantic action. */
mail~reset
spatialPayload=.directory~new
spatialPayload['requestedView']='MESSAGE'
r2=app~activateInteraction('spatial.enter-correspondence',message,spatialMessage,spatialPayload)
trace2=mail~trace
call assert r2='OPENED','spatial interaction reaches ordinary behaviour'

call assert trace1=trace2,'conventional and spatial routes produce identical semantic trace'
call assert mail~methodCalls=1,'spatial route fires ordinary behaviour exactly once'
call assert mail~lastSubject==message,'spatial route retains same live domain object identity'
call assert mail~lastAction='message.open','spatial vocabulary terminates at same semantic action'
call assert app~exposedObject('selectedMessage')==message,'3D app retains exposed live application object'
call assert app~exposedCapability('selectedMessage')='READ','spatial projection does not broaden capability'
call assert app~findEntryPoint('inbox')~action='message.open','entry point names semantic action, not renderer mechanic'

say 'TRACE' trace2
say 'PASS test_mail_spatial_equivalence'
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
addPath: procedure
  here=filespec('location',parse source . . src)
  call value 'REXX_PATH', here'../src:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'; return

::requires 'Wire3DAll.cls'

::class MailQualificationBehaviour
::attribute methodCalls get
::attribute lastAction get
::attribute lastSubject get
::attribute trace get
::method init
  self~reset
::method reset
  expose methodCalls lastAction lastSubject trace
  methodCalls=0; lastAction=''; lastSubject=.nil; trace=''
::method openMessage
  expose methodCalls lastAction lastSubject trace
  use strict arg event
  methodCalls=methodCalls+1
  lastAction=event~action
  lastSubject=event~subject
  identity=event~subject['identity']
  requested=event~payload['requestedView']
  /* Golden trace intentionally contains semantic facts only.  No click,
     gesture, coordinates, camera, geometry, DOM or native widget vocabulary. */
  trace='event='event~action'|subject='identity'|effect=OPEN_MESSAGE|view='requested
  return 'OPENED'
