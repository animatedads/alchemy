say "FLYLO GROK CHAT ASSISTANT START"
p=.CapturingChatProvider~new
a=.FlyLoGrokAssistant~new(p,"fixture-model",128)
r=a~assist("Where am I going?","BROWSER SESSION CONTEXT: PIK -> EWR","LEGAL EFFECT STATUS=NOT_EVALUATED","CUSTOMER: hello")
if \r~ok then do; say "FAIL reply"; exit 61; end
req=p~request
if req~prompt~pos("FLYLO CUSTOMER ASSISTANT")=0 then do; say "FAIL assistant role"; exit 62; end
if req~prompt~pos("RECENT CONVERSATION")=0 then do; say "FAIL conversation missing"; exit 63; end
if req~prompt~pos("BROWSER SESSION CONTEXT")=0 then do; say "FAIL context missing"; exit 64; end
if req~prompt~pos("Do not ask for full card numbers")=0 then do; say "FAIL credential boundary"; exit 65; end
if req~prompt~pos("transactional FlyLo authority")=0 then do; say "FAIL transaction boundary"; exit 66; end
say "FLYLO GROK CHAT ASSISTANT: OK"
exit 0
::class CapturingChatProvider
::attribute request get
::method complete
  expose request
  use arg requestArg
  request=requestArg
  return .AIProviderReply~success("fixture chat",request~model,"stop",.AIProviderUsage~new(5,7))
::requires "FlyLoGrokAssistant.cls"
