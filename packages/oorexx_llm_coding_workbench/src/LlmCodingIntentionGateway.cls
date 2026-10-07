/* Structured bridge into the existing Intention Service.
 * The service receives only an opaque token.  The action and slot payloads stay
 * as objects, including exact multiline Rexx method bodies.
 */
::class LlmCodingStructuredIntentionProvider public
::method init
  expose staged sequence
  staged=.directory~new
  sequence=0
::method name
  return "LLM_CODING_STRUCTURED"
::method stage
  expose staged sequence
  use strict arg decision
  sequence+=1
  token="WB"||sequence
  staged[token]=decision
  return token
::method propose
  expose staged
  use arg service,text
  offered=.array~new
  parse var text verb token
  if translate(strip(verb))\=="WORKBENCH_DECISION" then return offered
  token=strip(token)
  if token=="" then return offered
  if \staged~hasIndex(token) then return offered
  decision=staged[token]
  action=decision~action
  registration=service~registration(action)
  if registration==.nil then return offered
  proposal=.IntentionProposal~new(action,1000,self~name,.true,"structured LLM coding action")
  args=decision~args
  supplier=args~supplier
  do while supplier~available
    value=supplier~item
    if value\==.nil then proposal~putSlot(translate(supplier~index),value,.true)
    supplier~next
  end
  if action=="MATERIALISE" then do
    if proposal~slot("OUTPUT_PATH")==.nil then proposal~putSlot("OUTPUT_PATH","controller-owned",.true)
  end
  offered~append(proposal)
  return offered

::class LlmCodingIntentionGateway public
::attribute service get
::attribute provider get
::method init
  expose service provider
  use strict arg serviceArg
  if serviceArg==.nil then raise syntax 88.900 array("Intention Service object is required")
  service=serviceArg
  provider=.LlmCodingStructuredIntentionProvider~new
  service~registerProvider(provider)
::method interpret
  expose service provider
  use strict arg decision
  token=provider~stage(decision)
  return service~input("WORKBENCH_DECISION "||token)
::method commit
  expose service
  use strict arg decision
  if decision==.nil then raise syntax 88.900 array("intention decision required")
  if decision~status\=="READY" then raise syntax 88.900 array("only READY intention decisions may be committed")
  return service~dispatch(decision)

::requires "IntentionContext.cls"
