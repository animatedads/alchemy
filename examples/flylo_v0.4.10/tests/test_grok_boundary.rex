say "FLYLO GROK BOUNDARY START"
p=.CapturingProvider~new
a=.FlyLoGrokAssistant~new(p,"fixture-model",128)
r=a~explain("Can I get a refund?","flight FL101 cancelled; source=AS400","LEGAL EFFECT STATUS=CONDITIONAL; action=ISSUE_US_REFUND; trace=abc")
if \r~ok then do; say "FAIL reply"; exit 41; end
req=p~request
if req~prompt~pos("LEGAL EFFECT EVIDENCE")=0 then do; say "FAIL legal evidence missing"; exit 42; end
if req~prompt~pos("never create airline facts or legal entitlements")=0 then do; say "FAIL authority boundary missing"; exit 43; end
if req~prompt~pos("transactional FlyLo authority")=0 then do; say "FAIL transaction boundary missing"; exit 44; end
say "FLYLO GROK BOUNDARY: OK"
exit 0
::class CapturingProvider
::attribute request get
::method complete
  expose request
  use arg requestArg
  request=requestArg
  return .AIProviderReply~success("fixture explanation",request~model,"stop",.AIProviderUsage~new(5,7))
::requires "FlyLoGrokAssistant.cls"
