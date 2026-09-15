agentPath=arg(1)
if agentPath='' then agentPath='../tests/invocation_freshness_agent.rex'
now=.DateTime~new
subject='STAFF:BOB'
principal=.AccessPrincipal~new(subject,'bob-key-1')~seal
target=.InvocationPaymentTarget~new
objectId=target~alchemyObjectId
snapshot=.SecuritySnapshot~new('SNAP:INV-DEMO',subject,now)~seal
framework=.SecurityPolicyFramework~new('METHOD-SECURITY','1',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'security','risk')~seal
state=.InvocationResolverState~new(subject,snapshot,framework,'SESSION:STAFF:42')
policy=.PermissionPolicy~new('INV-DEMO-PERMISSIONS','1','DENY',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'security','risk')
policy~addRule(.PermissionRule~new('EXACT-RELEASE',100,'ALLOW',subject,objectId,'INVOCATIONPAYMENTTARGET','RELEASEPAYMENT','ALLOW',framework~semanticIdentity)~seal)
policy~seal
invPolicy=.SecurityInvocationPolicy~new('SM-FRESHNESS','1',30,5,.true,.true,.true,'security','risk')~seal
adapter=.SecurityInvocationAlchemyPermissionPolicyAdapter~new(principal,policy,.PermissionAuthority~new,state,state,invPolicy,.SecurityInvocationGuard~new,.AlchemySecurityPolicy~new('DENY'))
manager=.AlchemySecurityManager~new(adapter,.nil,.AlchemySecurityRuntimeProfile~observedR13196)
r=.Routine~newFile(agentPath); r~setSecurityManager(manager)
value=r~call(target,7)
say 'releasePayment(7) result='||value
say 'permission decisions='||adapter~decisionEnvelopes~items
say 'security trace binds ARGUMENT_IDENTITY=AMOUNT:7'
state~reusePrior(.true)
r2=.Routine~newFile(agentPath); r2~setSecurityManager(manager)
signal on syntax name denied
ignore=r2~call(target,700000)
signal off syntax
say 'ERROR stale Security assessment unexpectedly authorized changed arguments'
exit 1
denied:
  signal off syntax
say 'releasePayment(700000) with stale prior Security assessment=DENIED'
say 'target total remains='||target~total
say 'permission decisions still='||adapter~decisionEnvelopes~items||' (blocked before second Permission decision)'
say 'Bouncer evidence was exact-invocation evidence, not a bearer capability.'
exit 0

::class InvocationResolverState public
::method init
  expose expectedSubject snapshot framework contextIdentity priorAssessment reuse
  use strict arg expectedSubjectArg,snapshotArg,frameworkArg,contextIdentityArg
  expectedSubject=expectedSubjectArg; snapshot=snapshotArg; framework=frameworkArg; contextIdentity=contextIdentityArg
  priorAssessment=.nil; reuse=.false
::method reusePrior
  expose reuse
  use strict arg value
  reuse=value
::method argumentIdentityFor
  expose expectedSubject
  use strict arg principalId,obj,methodName,args,info
  if principalId<>expectedSubject then return ''
  amount=''
  if args~items>0 then amount=args[1]~string
  return 'AMOUNT:'||amount
::method contextIdentityFor
  expose expectedSubject contextIdentity
  use strict arg principalId,obj,methodName,args,info
  if principalId<>expectedSubject then return ''
  return contextIdentity
::method assessmentForInvocation
  expose expectedSubject snapshot framework priorAssessment reuse
  use strict arg principalId,obj,methodName,args,info,evidence
  if principalId<>expectedSubject then return .SecurityResult~failure('SUBJECT_MISMATCH')
  if reuse & priorAssessment<>.nil then return .SecurityResult~success(priorAssessment)
  if obj~hasMethod('ALCHEMYOBJECTID') then objectId=obj~alchemyObjectId
  else objectId=obj~identityHash~string
  ar=.SecurityMethodActionFactory~createInvocation('ACT:SM:'||evidence~invocationId,principalId,objectId,obj~class~id,methodName,evidence,.DateTime~new,'HIGH',methodName)
  if \ar~ok then return ar
  evaluated=.SecurityEffectEngine~new~evaluate(ar~value~seal,snapshot,framework)
  if evaluated~ok then priorAssessment=evaluated~value
  return evaluated

::class InvocationPaymentTarget subclass AlchemyObject
::attribute total get
::method init
  expose total
  total=0
  forward class (super) array (.nil,.nil,.nil) continue
::method releasePayment protected
  expose total
  use strict arg amount
  total+=amount
  return total

::requires 'SecurityEffect.cls'
::requires 'SecurityInvocationAlchemyPermissionsAdapter.cls'
::requires 'AlchemyObject.cls'
