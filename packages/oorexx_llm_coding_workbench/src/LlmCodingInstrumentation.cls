/* Rexx-native instrumentation for the LLM Coding Workbench.
 *
 * The trace deliberately retains the live Rexx objects supplied by the
 * workbench.  It does not serialise semantic objects into JSON or flatten them
 * into strings merely for observation.  Boundary projection is opt-in and is
 * intentionally shallow.
 */
::class LlmCodingTraceEvent public
::attribute sequence get
::attribute kind get
::attribute operation get
::attribute subject get
::attribute context get

::method init
  expose sequence kind operation subject context
  use strict arg sequenceArg,kindArg,operationArg,subjectArg=.nil,contextArg=.nil
  sequence=sequenceArg
  kind=translate(kindArg~string)
  operation=operationArg~string
  subject=subjectArg
  context=contextArg

::method asSummary
  expose sequence kind operation subject context
  d=.directory~new
  d["sequence"]=sequence
  d["kind"]=kind
  d["operation"]=operation
  d["subject_class"]=self~className(subject)
  d["context_class"]=self~className(context)
  return d

::method className private
  use strict arg value
  if value==.nil then return "NilObject"
  return value~class~id

::class LlmCodingInstrumentation public
::attribute enabled

::method init
  expose events nextSequence enabled
  use strict arg enabledArg=.true
  events=.array~new
  nextSequence=0
  enabled=enabledArg

::method record
  expose events nextSequence enabled
  use strict arg kind,operation,subject=.nil,context=.nil
  if \enabled then return .nil
  nextSequence+=1
  event=.LlmCodingTraceEvent~new(nextSequence,kind,operation,subject,context)
  events~append(event)
  return event

::method events
  expose events
  return events

::method last
  expose events
  if events~items=0 then return .nil
  return events[events~items]

::method clear
  expose events nextSequence
  events=.array~new
  nextSequence=0
  return self

::method summaries
  expose events
  out=.array~new
  do event over events
    out~append(event~asSummary)
  end
  return out
