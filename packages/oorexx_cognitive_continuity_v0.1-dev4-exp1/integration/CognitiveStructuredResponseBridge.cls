/* Experimental bridge only.
 * The supplied API roll-up did not contain a standalone platform Structured Response
 * implementation. This bridge makes the exact semantic outcome inspectable without
 * claiming to own the platform common response contract.
 */
::class CognitiveStructuredResponseBridge public
::constant SCHEMA "oorexx.cognitive.compat-structured-response/0.1"
::method wrap class
  use strict arg operationResult, operation='', actorId=''
  out=.directory~new
  out['schema']=self~SCHEMA
  out['compatibilityOnly']=.true
  out['operation']=operation
  if operationResult~ok then out['status']='SUCCESS'; else out['status']='ERROR'
  out['code']=operationResult~code
  out['detail']=operationResult~detail
  out['result']=operationResult~value
  out['evidence']=.array~new
  out['warnings']=.array~new
  errors=.array~new
  if \operationResult~ok then do
    e=.directory~new; e['code']=operationResult~code; e['detail']=operationResult~detail; errors~append(e)
  end
  out['errors']=errors
  provenance=.directory~new; provenance['actorId']=actorId; provenance['component']='oorexx-cognitive-continuity'; provenance['version']=.CognitiveBuild~VERSION
  out['provenance']=provenance
  timing=.directory~new; timing['completedAt']=.CognitiveUtil~now; out['timing']=timing
  authority=.directory~new; authority['note']='Authority fields in cognitive records are server-derived; this compatibility response is not authority.'; out['authority']=authority
  return out
::requires 'CognitiveContinuity.cls'
