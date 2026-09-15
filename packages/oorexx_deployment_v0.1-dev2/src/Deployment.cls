/* General ooRexx Deployment model v0.1-dev2.
 * Application-neutral reconciliation: desired state + observed target state
 * -> plan -> apply -> fresh verification.
 */
::options numeric inherit

::class DeploymentTarget public
::method init
  expose targetId transport workingRoot metadata
  use strict arg targetId, transport='local', workingRoot='', metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method targetId; expose targetId; return targetId
::method transport; expose transport; return transport
::method workingRoot; expose workingRoot; return workingRoot
::method metadata; expose metadata; return metadata

::class DeploymentCapability public
::method init
  expose name value source
  use strict arg name, value=.true, source='discovery'
::method name; expose name; return name
::method value; expose value; return value
::method source; expose source; return source

::class DeploymentDiscovery public
::method init
  expose target facts capabilities observedAt
  use strict arg target, observedAt=''
  facts=.directory~new; capabilities=.directory~new
::method target; expose target; return target
::method observedAt; expose observedAt; return observedAt
::method putFact
  expose facts
  use strict arg name,value
  facts[name~string]=value; return self
::method fact
  expose facts
  use strict arg name, default=.nil
  if facts~hasIndex(name~string) then return facts[name~string]
  return default
::method addCapability
  expose capabilities
  use strict arg capability
  capabilities[capability~name]=capability; return self
::method hasCapability
  expose capabilities
  use strict arg name
  return capabilities~hasIndex(name~string)
::method capability
  expose capabilities
  use strict arg name
  if capabilities~hasIndex(name~string) then return capabilities[name~string]
  return .nil

::class DeploymentRequirement public
::method init
  expose id kind expected required metadata
  use strict arg id,kind,expected='',required=.true,metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method id; expose id; return id
::method kind; expose kind; return kind
::method expected; expose expected; return expected
::method required; expose required; return required
::method metadata; expose metadata; return metadata
::method explain
  expose id kind expected required
  return 'requirement='||id||' kind='||kind||' expected='||expected||' required='||required

::class DeploymentAssessmentItem public
::method init
  expose requirement actual satisfied reason
  use strict arg requirement,actual,satisfied,reason=''
::method requirement; expose requirement; return requirement
::method actual; expose actual; return actual
::method satisfied; expose satisfied; return satisfied
::method reason; expose reason; return reason

::class DeploymentAssessment public
::method init
  expose items
  items=.array~new
::method add
  expose items
  use strict arg item
  items~append(item); return self
::method items; expose items; return items~copy
::method satisfied
  expose items
  do item over items
    if item~requirement~required & \item~satisfied then return .false
  end
  return .true
::method unsatisfied
  expose items
  out=.array~new
  do item over items
    if \item~satisfied then out~append(item)
  end
  return out

::class DeploymentArtifact public
::method init
  expose artifactId source destination hashAlgorithm hash metadata
  use strict arg artifactId,source,destination='',hashAlgorithm='sha256',hash='',metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method artifactId; expose artifactId; return artifactId
::method source; expose source; return source
::method destination; expose destination; return destination
::method hashAlgorithm; expose hashAlgorithm; return hashAlgorithm
::method hash; expose hash; return hash
::method metadata; expose metadata; return metadata

::class DeploymentVerification public
::method init
  expose id command expectedExit metadata
  use strict arg id,command,expectedExit=0,metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method id; expose id; return id
::method command; expose command; return command
::method expectedExit; expose expectedExit; return expectedExit
::method metadata; expose metadata; return metadata

::class DeploymentManifest public
::method init
  expose manifestId manifestVersion requirements artifacts verifications metadata policy
  use strict arg manifestId, manifestVersion='1', metadata=.nil
  requirements=.array~new; artifacts=.array~new; verifications=.array~new
  if metadata==.nil then metadata=.directory~new
  policy=.directory~new
::method manifestId; expose manifestId; return manifestId
::method manifestVersion; expose manifestVersion; return manifestVersion
::method metadata; expose metadata; return metadata
::method policy; expose policy; return policy
::method addRequirement
  expose requirements
  use strict arg requirement
  requirements~append(requirement); return self
::method addArtifact
  expose artifacts
  use strict arg artifact
  artifacts~append(artifact); return self
::method addVerification
  expose verifications
  use strict arg verification
  verifications~append(verification); return self
::method requirements; expose requirements; return requirements~copy
::method artifacts; expose artifacts; return artifacts~copy
::method verifications; expose verifications; return verifications~copy

::class DeploymentAction public
::method init
  expose actionId actionType reason requirement provider destructive reversible metadata
  use strict arg actionId,actionType,reason,requirement=.nil,provider='',destructive=.false,reversible=.false,metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method actionId; expose actionId; return actionId
::method actionType; expose actionType; return actionType
::method reason; expose reason; return reason
::method requirement; expose requirement; return requirement
::method provider; expose provider; return provider
::method destructive; expose destructive; return destructive
::method reversible; expose reversible; return reversible
::method metadata; expose metadata; return metadata
::method explain
  expose actionId actionType reason
  return 'action='||actionId||' type='||actionType||' reason='||reason

::class DeploymentPlan public
::method init
  expose target manifest discovery assessment actions executable failureReason
  use strict arg target,manifest,discovery,assessment
  actions=.array~new; executable=.true; failureReason=''
::method target; expose target; return target
::method manifest; expose manifest; return manifest
::method discovery; expose discovery; return discovery
::method assessment; expose assessment; return assessment
::method addAction
  expose actions
  use strict arg action
  actions~append(action); return self
::method actions; expose actions; return actions~copy
::method executable; expose executable; return executable
::method failureReason; expose failureReason; return failureReason
::method fail
  expose executable failureReason
  use strict arg reason
  executable=.false; failureReason=reason; return self
::method noActionRequired
  expose actions executable
  return executable & actions~items=0

::class DeploymentActionResult public
::method init
  expose action success reason evidence
  use strict arg action,success,reason='',evidence=''
::method action; expose action; return action
::method success; expose success; return success
::method reason; expose reason; return reason
::method evidence; expose evidence; return evidence

::class DeploymentResult public
::method init
  expose target manifest plan actionResults finalDiscovery verification satisfied failureReason evidence
  use strict arg target,manifest,plan
  actionResults=.array~new; finalDiscovery=.nil; verification=.nil
  satisfied=.false; failureReason=''; evidence=.directory~new
::method addActionResult; expose actionResults; use strict arg r; actionResults~append(r); return self
::method actionResults; expose actionResults; return actionResults~copy
::method setVerification
  expose finalDiscovery verification satisfied failureReason
  use strict arg discovery,assessment
  finalDiscovery=discovery; verification=assessment; satisfied=assessment~satisfied
  if \satisfied then failureReason='post-deployment observed state does not satisfy manifest'
  return self
::method fail
  expose satisfied failureReason
  use strict arg reason
  satisfied=.false; failureReason=reason; return self
::method satisfied; expose satisfied; return satisfied
::method failureReason; expose failureReason; return failureReason
::method finalDiscovery; expose finalDiscovery; return finalDiscovery
::method verification; expose verification; return verification
::method evidence; expose evidence; return evidence

::class DeploymentProvider public
::method name; return 'abstract'
::method discover
  use strict arg target,manifest
  raise syntax 88.900 array('DeploymentProvider discover not implemented')
::method assessRequirement
  use strict arg target,requirement,discovery,manifest
  raise syntax 88.900 array('DeploymentProvider assessRequirement not implemented')
::method actionFor
  use strict arg target,item,discovery,manifest,actionNumber
  return .nil
::method applyAction
  use strict arg target,action,manifest
  raise syntax 88.900 array('DeploymentProvider applyAction not implemented')

::class Deployment public
::method init
  expose provider
  use strict arg provider
::method discover
  expose provider
  use strict arg target,manifest
  return provider~discover(target,manifest)
::method assess
  expose provider
  use strict arg target,manifest,discovery=.nil
  if discovery==.nil then discovery=provider~discover(target,manifest)
  assessment=.DeploymentAssessment~new
  do req over manifest~requirements
    assessment~add(provider~assessRequirement(target,req,discovery,manifest))
  end
  return assessment
::method plan
  expose provider
  use strict arg target,manifest,discovery=.nil,assessment=.nil
  if discovery==.nil then discovery=provider~discover(target,manifest)
  if assessment==.nil then assessment=self~assess(target,manifest,discovery)
  plan=.DeploymentPlan~new(target,manifest,discovery,assessment)
  n=0
  do item over assessment~unsatisfied
    n+=1
    action=provider~actionFor(target,item,discovery,manifest,n)
    if action==.nil then return plan~fail('no permitted action for '||item~requirement~id||': '||item~reason)
    plan~addAction(action)
  end
  return plan
::method apply
  expose provider
  use strict arg plan
  result=.DeploymentResult~new(plan~target,plan~manifest,plan)
  if \plan~executable then return result~fail(plan~failureReason)
  do action over plan~actions
    ar=provider~applyAction(plan~target,action,plan~manifest)
    result~addActionResult(ar)
    if \ar~success then return result~fail('action failed '||action~actionId||': '||ar~reason)
  end
  fresh=provider~discover(plan~target,plan~manifest)
  checked=self~assess(plan~target,plan~manifest,fresh)
  return result~setVerification(fresh,checked)
::method verify
  expose provider
  use strict arg target,manifest
  fresh=provider~discover(target,manifest)
  return self~assess(target,manifest,fresh)
::method reconcile
  use strict arg target,manifest
  discovery=self~discover(target,manifest)
  assessment=self~assess(target,manifest,discovery)
  plan=self~plan(target,manifest,discovery,assessment)
  return self~apply(plan)
