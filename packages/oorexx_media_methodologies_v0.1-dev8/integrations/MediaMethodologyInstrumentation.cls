/* Instrumentation Mesh event adapter for methodology execution.
 *
 * API: media.methodologies.instrumentation/0.1
 *
 * These are operational execution observations only.  They never assert that a
 * reconstructed feature existed in the source and never acquire media evidence
 * authority.  Instrumentation Mesh retains/replays the events under the named
 * MEDIA_METHODOLOGY_EXECUTION authority.
 */
::class MediaMethodologyInstrumentation public
::constant AUTHORITY "MEDIA_METHODOLOGY_EXECUTION"
::method init
  expose journal
  use strict arg maximumEvents=128
  journal=.InstrumentationEventJournal~new(maximumEvents)

::method started
  expose journal
  use strict arg eventId,subjectRef,methodologyId,implementationId,observedAt="",correlationId="",operationId="",relatedRefs=.nil
  evidence=self~evidence(methodologyId,implementationId,"STARTED","","",.nil)
  event=.InstrumentationCodec~event(eventId,"METHODOLOGY_EXECUTION_STARTED",subjectRef,self~AUTHORITY,observedAt,"INFO",correlationId,operationId,"methodology execution started",relatedRefs,evidence,.nil,.false)
  journal~append(event)
  return event

::method completed
  expose journal
  use strict arg eventId,subjectRef,methodologyId,implementationId,outputRef,observedAt="",correlationId="",operationId="",relatedRefs=.nil
  evidence=self~evidence(methodologyId,implementationId,"COMPLETED",outputRef,"",.nil)
  event=.InstrumentationCodec~event(eventId,"METHODOLOGY_EXECUTION_COMPLETED",subjectRef,self~AUTHORITY,observedAt,"INFO",correlationId,operationId,"derived output completed",relatedRefs,evidence,.nil,.false)
  journal~append(event)
  return event

::method notApplicable
  expose journal
  use strict arg eventId,subjectRef,methodologyId,implementationId,reasonCode,observedAt="",correlationId="",operationId="",relatedRefs=.nil
  evidence=self~evidence(methodologyId,implementationId,"NOT_APPLICABLE","",reasonCode,.nil)
  event=.InstrumentationCodec~event(eventId,"METHODOLOGY_NOT_APPLICABLE",subjectRef,self~AUTHORITY,observedAt,"INFO",correlationId,operationId,"methodology withheld by applicability evidence",relatedRefs,evidence,.nil,.false)
  journal~append(event)
  return event

::method failed
  expose journal
  use strict arg eventId,subjectRef,methodologyId,implementationId,reasonCode,observedAt="",correlationId="",operationId="",relatedRefs=.nil
  evidence=self~evidence(methodologyId,implementationId,"FAILED","",reasonCode,.nil)
  event=.InstrumentationCodec~event(eventId,"METHODOLOGY_EXECUTION_FAILED",subjectRef,self~AUTHORITY,observedAt,"WARN",correlationId,operationId,"methodology provider execution failed",relatedRefs,evidence,.nil,.false)
  journal~append(event)
  return event

::method events
  expose journal
  return journal~events

::method evidence
  use strict arg methodologyId,implementationId,status,outputRef,reasonCode,extra
  d=.Directory~new
  d["schema"]="media-methodologies.instrumentation-evidence/0.1"
  d["methodology_id"]=translate(strip(methodologyId))
  d["implementation_id"]=strip(implementationId)
  d["status"]=translate(strip(status))
  d["output_ref"]=strip(outputRef)
  d["reason_code"]=strip(reasonCode)
  d["observation_promotion"]=.false
  d["source_authority_unchanged"]=.true
  if extra<>.nil then d["extra"]=extra
  return d

::requires "InstrumentationMesh.cls"
::requires "InstrumentationServiceAdapters.cls"
