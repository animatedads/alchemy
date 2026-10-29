/* Optional emitter for instrumentation.mesh/0.1 (not financial authority).
 * The owned ledger remains the source for costs and commitments.
 */
::class CloudEconomicsInstrumentation public
::method init
  expose emitter
  use strict arg identity
  emitter=.InstrumentationEmitter~new(identity)
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  emitter~gaugeSet('cloud.economics.state','PAPER_ONLY','state',.nil,.InstrumentationMetricKind~STATE)

::method observed
  expose emitter
  use strict arg providersObserved, providersMissing
  emitter~counterAdd('cloud.economics.observation.cycles.total',1)
  emitter~gaugeSet('cloud.economics.providers.observed',providersObserved,'count')
  emitter~gaugeSet('cloud.economics.providers.unconfigured',providersMissing,'count')
  return self

::method evaluated
  expose emitter
  use strict arg decision
  emitter~requestAccepted
  select
    when decision['status']=='PAPER_BUY' then do
      emitter~requestCompleted
      emitter~counterAdd('cloud.economics.paper.buy.total',1)
    end
    when decision['status']=='PAPER_HOLD' then do
      emitter~requestCompleted
      emitter~counterAdd('cloud.economics.paper.hold.total',1)
    end
    otherwise do
      emitter~requestRejected
      emitter~counterAdd('cloud.economics.ineligible.total',1)
    end
  end
  return self

::method snapshot
  expose emitter
  use strict arg observedAt=''
  return emitter~snapshot(observedAt)

::requires 'InstrumentationMesh.cls'
