/* Browser-side ooRexx via Josep Maria Blasco's ooRexx/WASM .JSObject.
   No JavaScript business logic; DOM events and HTTP handling are ooRexx. */
doc=.js~page~document
app=.DummyChatApplication~new(doc)
controller=.BrowserContinuation~new(doc,app)
controller~start('receiveLoop')

::requires 'js.cls'

::class DummyChatApplication
::attribute completedId get

::method init
  expose doc currentChat currentEventId completedId
  use strict arg doc
  currentChat=''
  currentEventId=''
  completedId=''
  doc~getElementById('chat-ops')~addEventListener('click',.js~handler(self,'selectOps'))
  doc~getElementById('chat-rf')~addEventListener('click',.js~handler(self,'selectRasen'))
  doc~getElementById('chat-general')~addEventListener('click',.js~handler(self,'selectGeneral'))
  doc~getElementById('send')~addEventListener('click',.js~handler(self,'send'))
  doc~getElementById('composer')~addEventListener('keydown',.js~handler(self,'onKey'))
  self~restore
  self~selectRasen
  doc~getElementById('runtime')~textContent='Browser ooRexx ready'

::method selectOps
  self~selectChat('operations','Operations')

::method selectRasen
  self~selectChat('rasen-falcon','Rasen Falcon')

::method selectGeneral
  self~selectChat('general','General')

::method selectChat
  expose doc currentChat
  use strict arg id,title
  currentChat=id
  do section over doc~querySelectorAll('[data-conversation]')~makeArray
    if section~id=='messages-'||id then section~removeAttribute('hidden')
    else section~setAttribute('hidden','')
  end
  doc~getElementById('conversation-title')~textContent=title
  nodes=doc~querySelectorAll('[data-chat-id]')~makeArray
  do node over nodes
    if node~getAttribute('data-chat-id')==id then node~setAttribute('aria-current','true')
    else node~setAttribute('aria-current','false')
  end

::method expect
  expose currentEventId completedId
  use strict arg eventId
  currentEventId=eventId
  completedId=''

::method onKey
  use strict arg event
  if event~key=='Enter' then do
    event~preventDefault
    self~send
  end

::method appendMessage
  expose doc
  use strict arg chatId,text
  history=doc~getElementById('messages-'||chatId)
  if history==.nil then return .false
  card=doc~createElement('div')
  card~className='message'
  card~textContent=text
  history~appendChild(card)
  return .true

::method restore
  expose doc
  storage=.js~page~localStorage
  do i=0 to storage~length-1
    key=storage~key(i)
    if key~left(14)<>'alchemy-event:' then iterate
    saved=storage~getItem(key)
    tab='09'x
    parse var saved target (tab) message
    if target<>'' & message<>'' then ignored=self~appendMessage(target,message)
  end

::method send
  expose doc currentChat currentEventId completedId
  text=doc~getElementById('composer')~value~strip
  if text='' | currentChat='' then return
  if currentEventId<>'' then do
    key='alchemy-event:'||currentEventId
    storage=.js~page~localStorage
    existing=storage~getItem(key)
    if existing<>.nil then do
      completedId=currentEventId
      currentEventId=''
      doc~getElementById('composer')~value=''
      return
    end
    /* Persist the toy application's transcript before reporting completion.
       Reload reconstructs the UI, unlike an ephemeral DOM-only message. */
    storage~setItem(key,currentChat||'09'x||text)
  end
  ignored=self~appendMessage(currentChat,text)
  doc~getElementById('composer')~value=''
  if currentEventId<>'' then do
    completedId=currentEventId
    currentEventId=''
  end
  doc~getElementById('last-action')~textContent='Message sent in '||currentChat

::class BrowserContinuation
::method init
  expose doc app sessionId
  use strict arg doc,app
  sessionId=.js~crypto~randomUUID
  doc~getElementById('register-watch')~addEventListener('click',.js~handler(self,'registerWatch'))
  doc~getElementById('trigger-create')~addEventListener('click',.js~handler(self,'createFlag'))
  doc~getElementById('trigger-remove')~addEventListener('click',.js~handler(self,'removeFlag'))

::method post
  use strict arg path,body=''
  options=.js~Object~new
  options['method']='POST'
  options['body']=body
  response=.js~fetch(path,options)~await
  return response~status==200

::method registerWatch
  expose doc
  if self~post('/api/register','WATCH-READY') then doc~getElementById('runtime')~textContent='Watch registered with native ooRexx runtime'

::method createFlag
  expose doc
  if self~post('/api/demo/create') then doc~getElementById('source-status')~textContent='File created on host'

::method removeFlag
  expose doc
  if self~post('/api/demo/remove') then doc~getElementById('source-status')~textContent='File removed (re-armed)'

::method locate
  expose doc
  use strict arg targetId
  nodes=doc~querySelectorAll('[data-chat-id]')~makeArray
  do node over nodes
    if node~getAttribute('data-chat-id')==targetId then return node
  end
  return .nil

::method deliver
  expose doc app sessionId
  use strict arg line
  tab='09'x
  parse var line eventId (tab) target (tab) message
  if eventId='' | target='' | message='' then return .false
  permit=eventId||'09'x||sessionId
  if \self~post('/api/claim',permit) then return .false
  if \self~post('/api/received',permit) then return .false
  link=self~locate(target)
  if link==.nil then do
    doc~getElementById('runtime')~textContent='Unknown chat '||target||'; no completion acknowledged'
    return .false
  end
  /* DEMO ONLY: issue the real DOM clicks on the controlled dummy app. */
  app~expect(eventId)
  link~click
  doc~getElementById('composer')~value=message
  doc~getElementById('send')~click
  if app~completedId<>eventId then return .false
  if \self~post('/api/complete',permit) then return .false
  doc~getElementById('runtime')~textContent='Completed and acknowledged '||eventId
  return .true

::method receiveLoop unguarded
  expose doc
  signal on syntax name receiveError
  do forever
    response=.js~fetch('/api/next')~await
    if response~status==200 then do
      line=response~text~await
      ignored=self~deliver(line)
    end
    else if response~status<>204 then do
      doc~getElementById('runtime')~textContent='Transport HTTP '||response~status
      leave
    end
  end
  return
receiveError:
  doc~getElementById('runtime')~textContent='Transport error; pending event retained. Reload the page.'
  return
