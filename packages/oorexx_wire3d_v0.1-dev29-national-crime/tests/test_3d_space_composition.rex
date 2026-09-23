call addPath

mail=.MailBehaviour~new
mailApp=.Wire3DSpaceApp~new('mailclient','wire-app://mail-hub','1.0')
msg=.directory~new; msg['id']='mailbox|77|1042'
mailApp~expose('selectedMessage',msg,'READ')
msg3d=mailApp~project('selectedMessage','mail-message-1042',.Wire3DRepresentation~new('correspondence','Selected message','application'))
mailApp~bind('message.reply',mail,'reply','USE')
mailApp~mapInteraction('spatial.reply','message.reply')
mailApp~entryPoint('inbox','selectedMessage','')

payload=.directory~new; payload['body']='same-code'
r=mailApp~activateInteraction('spatial.reply',msg,msg3d,payload)
call assert r='REPLIED','spatial interaction maps to existing behaviour'
call assert mail~calls=1,'same ordinary behaviour fired once'
call assert mail~lastAction='message.reply','mapped interaction preserves semantic action'

ops=.Wire3DSpaceApp~new('operations','wire-app://operations','1.0')
ops~mount(mailApp)
call assert ops~mountedApp('mailclient')==mailApp,'mounted application retains live identity'
call assert mailApp~parent==ops,'mounted application participates in spatial containment'
call assert ops~childObjects[1]==mailApp,'application-within-application uses ordinary container semantics'
call assert mailApp~findEntryPoint('inbox')~targetName='selectedMessage','entry point resolves semantic target name'

snap=ops~asDirectory
call assert snap['mounts'][1]['appId']='mailclient','mount metadata serialises without copying child application truth'
ms=mailApp~asDirectory
call assert ms['interactions'][1]['action']='message.reply','interaction mapping serialises semantic action'
call assert ms['entryPoints'][1]['name']='inbox','entry point is inspectable semantic metadata'

say 'PASS test_3d_space_composition'
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
::attribute lastAction get
::method init
  expose calls lastAction
  calls=0; lastAction=''
::method reply
  expose calls lastAction
  use strict arg event
  calls=calls+1; lastAction=event~action
  return 'REPLIED'
