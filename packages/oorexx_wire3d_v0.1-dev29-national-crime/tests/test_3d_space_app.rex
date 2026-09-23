call addPath

mail=.MailBehaviour~new
app=.Wire3DSpaceApp~new('mailclient','wire-app://mail-hub','1.0')
message=.directory~new; message['id']='mailbox|77|1042'; message['subject']='Wire3D'
app~expose('selectedMessage',message,'READ')
rep=.Wire3DRepresentation~new('correspondence','Selected message','application')
projection=app~project('selectedMessage','mail-message-1042',rep)
app~bind('message.reply',mail,'reply','USE')

call assert app~appId='mailclient','application identity'
call assert projection~target==message,'projection retains live application object'
call assert projection~semanticRef='wire-app://mail-hub#selectedMessage','stable semantic reference'
call assert projection~metadata['capability']='READ','projection carries bounded capability metadata'
call assert app~hasBinding('message.reply'),'semantic action binding exists'

payload=.directory~new; payload['body']='Same behaviour, different space.'
r=app~activate('message.reply',message,projection,payload)
call assert r='REPLIED','3D activation returns ordinary behaviour result'
call assert mail~calls=1,'ordinary application behaviour fired exactly once'
call assert mail~lastSubject==message,'same live subject reached behaviour'
call assert mail~lastAction='message.reply','same semantic action reached behaviour'
call assert mail~lastBody='Same behaviour, different space.','payload preserved'

snapshot=app~asDirectory
call assert snapshot['representation']['kind']='application','application is a spatial object/container'
call assert snapshot['bindings'][1]['action']='message.reply','binding is inspectable semantic metadata'
call assert snapshot['exposed'][1]['name']='selectedMessage','exposure is inspectable without serialising target object'

say 'PASS test_3d_space_app'
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
addPath: procedure
  here=filespec('location',parse source . . src)
  call value 'REXX_PATH', here'../src:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'; return

::requires 'Wire3DAll.cls'

::class MailBehaviour
::attribute calls get
::attribute lastSubject get
::attribute lastAction get
::attribute lastBody get
::method init
  expose calls lastSubject lastAction lastBody
  calls=0; lastSubject=.nil; lastAction=''; lastBody=''
::method reply
  expose calls lastSubject lastAction lastBody
  use strict arg event
  calls=calls+1
  lastSubject=event~subject
  lastAction=event~action
  lastBody=event~payload['body']
  return 'REPLIED'
