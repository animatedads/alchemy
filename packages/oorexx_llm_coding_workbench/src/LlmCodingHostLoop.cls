/* Host-side coding loop.  SCCD/Desk, Intention Service, API Client and project
 * verification are supplied by the host; this class composes them. */
::class LlmCodingHostLoop public
::attribute workbench get
::attribute maxTurns get
::attribute verifier get

::method init
  expose workbench maxTurns verifier
  use strict arg workbenchArg,maxTurnsArg=20,verifierArg=.nil
  workbench=workbenchArg
  maxTurns=maxTurnsArg
  verifier=verifierArg

::method runMethodChallenge
  expose workbench maxTurns verifier
  use strict arg challenge,className,methodName
  do turnNo=1 to maxTurns
    turn=workbench~prepareMethodTurn(challenge,className,methodName)
    choice=workbench~ask(turn)
    outcome=workbench~apply(choice)
    if choice~action=="REPORT" then do
      if outcome~hasIndex("workbench_status") then if outcome["workbench_status"]=="COMPLETE" then return outcome
    end
    if outcome~hasIndex("intention_status") then do
      if outcome["intention_status"]=="CLARIFY" | outcome["intention_status"]=="CONFIRM" then iterate
    end
    if verifier\==.nil then do
      evidence=verifier~verify(workbench,choice,outcome,challenge,className,methodName)
      if evidence\==.nil then workbench~observe(evidence)
    end
  end
  raise syntax 88.900 array("coding challenge exceeded maximum turns")

::requires "LlmCodingWorkbench.cls"
