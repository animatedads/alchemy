/* fixture.rex -- browser-side behaviour of the test chat apps: composer, send, streamed reply.
 * Runs in the page on ooRexx/WASM (Josep Maria Blasco's runtime, .JSObject bridge).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 * Shape-neutral: the page's <body> carries data-fx-conversation, data-fx-busy-attr, data-fx-busy, data-fx-done,
 * and two <template>s (fx-user, fx-assistant) holding the shape's landmark markup.  A reply streams in from
 * /api/reply (long poll); the assistant turn carries the busy value until the reply is complete.
 */
doc=.js~page~document
chat=.FixtureChat~new(doc)

::requires 'js.cls'

::class FixtureChat
::method init
  expose doc conv busyAttr busyValue doneValue
  use strict arg doc
  b=doc~body
  conv=b~getAttribute('data-fx-conversation')
  busyAttr=b~getAttribute('data-fx-busy-attr')
  busyValue=b~getAttribute('data-fx-busy')
  doneValue=b~getAttribute('data-fx-done')
  doc~getElementById('fx-send')~addEventListener('click', .js~handler(self, 'send'))
  doc~getElementById('fx-status')~textContent='ready'

/* A turn element from a template; its text goes in [data-fx-text] when present, else in the element. */
::method turn
  expose doc busyValue
  use strict arg templateId, text
  html=doc~getElementById(templateId)~innerHTML
  wrapper=doc~createElement('div')
  wrapper~innerHTML=html~changeStr('{TEXT}', '')~changeStr('{STATE}', busyValue)
  node=wrapper~firstElementChild
  self~setText(node, text)
  return node
::method setText
  use strict arg node, text
  slot=node~querySelector('[data-fx-text]')
  if slot~isNil then node~textContent=text
  else slot~textContent=text

::method send
  expose doc conv busyAttr doneValue
  composer=doc~querySelector('[contenteditable="true"]')
  text=composer~textContent~strip
  if text='' then return
  composer~textContent=''
  /* a slow page: the composer clears at once, the user turn appears later (set by /api/turn-delay) */
  delay=doc~body~getAttribute('data-fx-turn-delay')
  if datatype(delay, 'W') then if delay>0 then do
    slept=.js~fetch('/api/sleep?seconds='delay)~await
  end
  turns=doc~getElementById('fx-turns')
  turns~appendChild(self~turn('fx-user', text))
  reply=self~turn('fx-assistant', '')
  turns~appendChild(reply)
  status=doc~getElementById('fx-status')
  status~textContent='sending'
  options=.js~Object~new
  options['method']='POST'
  options['body']=conv'09'x||text
  response=.js~fetch('/api/send', options)~await
  if response~status<>200 then do
    status~textContent='send failed' response~status
    return
  end
  turnId=response~text~await
  seen=0
  do forever
    r=.js~fetch('/api/reply?turn='turnId'&seen='seen)~await
    if r~status<>200 then do
      status~textContent='reply failed' r~status
      return
    end
    parse value r~text~await with done '09'x sofar
    self~setText(reply, sofar)
    seen=sofar~length
    if done=1 then leave
  end
  reply~setAttribute(busyAttr, doneValue)
  status~textContent='replied'
