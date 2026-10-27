/* InstrumentationAnalysis.cls
 * Read-only usage summaries over retained counter series.
 *
 * The collector remains the history authority. This helper groups counter
 * points by metric dimensions and derives reset-aware deltas. It does not
 * invent wall-clock time; callers may supply an independently measured elapsed
 * duration when a per-second rate is required.
 */

::class InstrumentationAnalysisBuild public
::constant VERSION "0.1-dev5"
::constant API "instrumentation.analysis/0.1"

::class InstrumentationUsageAnalyzer public
::method init
  expose collector
  use strict arg collectorArg
  if collectorArg==.nil then raise syntax 88.900 array("instrumentation usage analyzer requires a collector")
  collector=collectorArg

::method counterUsage
  expose collector
  use strict arg semanticRef,metricName,limit=0,elapsedSeconds=0
  points=collector~series(semanticRef,metricName,.nil,limit)
  groups=.directory~new

  do point over points
    if .InstrumentationCodec~value(point,"kind","")<>.InstrumentationMetricKind~COUNTER then iterate
    dimensions=.InstrumentationCodec~copyDirectory(point["dimensions"])
    groupKey=.InstrumentationCodec~dimensionKey(dimensions)
    state=groups[groupKey]
    if state==.nil then do
      state=.directory~new
      state["semantic_ref"]=semanticRef~string
      state["metric"]=metricName~string
      state["unit"]=.InstrumentationCodec~value(point,"unit","")
      state["dimensions"]=dimensions
      state["first_observed_at"]=.InstrumentationCodec~value(point,"observed_at","")
      state["last_observed_at"]=.InstrumentationCodec~value(point,"observed_at","")
      state["first_value"]=point["value"]
      state["last_value"]=point["value"]
      state["previous_value"]=point["value"]
      state["delta"]=0
      state["points"]=1
      state["reset_detected"]=.false
      groups[groupKey]=state
      iterate
    end

    previous=state["previous_value"]
    current=point["value"]
    if datatype(previous,"N") then do
      if datatype(current,"N") then do
        if current>=previous then state["delta"]+=current-previous
        else do
          /* A source restart/reset is visible rather than treated as negative
           * usage. The post-reset counter value contributes to the new epoch. */
          state["delta"]+=current
          state["reset_detected"]=.true
        end
      end
    end
    state["previous_value"]=current
    state["last_value"]=current
    state["last_observed_at"]=.InstrumentationCodec~value(point,"observed_at","")
    state["points"]+=1
  end

  out=.array~new
  do groupKey over groups
    state=groups[groupKey]
    state~remove("previous_value")
    if datatype(elapsedSeconds,"N") then do
      if elapsedSeconds>0 then do
        state["elapsed_seconds"]=elapsedSeconds
        state["per_second"]=state["delta"]/elapsedSeconds
      end
    end
    out~append(.InstrumentationCodec~copyDirectory(state))
  end
  return out


/* Publication freshness is about the observation path, not service health.
 * The caller supplies an authoritative POSIX-second instant, normally from the
 * Single Time Service or another qualified clock provider.  This helper never
 * parses local time strings and never converts stale telemetry into service
 * failure authority. */
::class InstrumentationFreshness public
::constant FRESH "FRESH"
::constant LATE "LATE"
::constant STALE "STALE"
::constant UNKNOWN "UNKNOWN"

::class InstrumentationFreshnessAssessor public
::method init
  expose collector
  use strict arg collectorArg
  if collectorArg==.nil then raise syntax 88.900 array("instrumentation freshness assessor requires a collector")
  collector=collectorArg

::method assess
  expose collector
  use strict arg semanticRef,nowPosixSeconds,freshWithinSeconds=30,staleAfterSeconds=120
  numeric digits 20
  if \datatype(nowPosixSeconds,"W") then return self~assessmentResult(.InstrumentationFreshness~UNKNOWN,"NOW_TIME_INVALID",.nil,.nil,freshWithinSeconds,staleAfterSeconds)
  if \datatype(freshWithinSeconds,"W") | freshWithinSeconds<0 then return self~assessmentResult(.InstrumentationFreshness~UNKNOWN,"FRESH_WINDOW_INVALID",.nil,.nil,freshWithinSeconds,staleAfterSeconds)
  if \datatype(staleAfterSeconds,"W") | staleAfterSeconds<freshWithinSeconds then return self~assessmentResult(.InstrumentationFreshness~UNKNOWN,"STALE_WINDOW_INVALID",.nil,.nil,freshWithinSeconds,staleAfterSeconds)

  evidence=collector~publicationEvidence(semanticRef)
  if evidence==.nil then return self~assessmentResult(.InstrumentationFreshness~UNKNOWN,"NO_PUBLICATION_EVIDENCE",.nil,.nil,freshWithinSeconds,staleAfterSeconds)
  published=evidence["published_posix_seconds"]
  if published==.nil | \datatype(published,"W") then return self~assessmentResult(.InstrumentationFreshness~UNKNOWN,"NO_AUTHORITATIVE_PUBLICATION_TIME",.nil,evidence,freshWithinSeconds,staleAfterSeconds)
  age=nowPosixSeconds-published
  if age<0 then return self~assessmentResult(.InstrumentationFreshness~UNKNOWN,"PUBLICATION_TIME_IN_FUTURE",age,evidence,freshWithinSeconds,staleAfterSeconds)
  if age<=freshWithinSeconds then status=.InstrumentationFreshness~FRESH
  else if age<=staleAfterSeconds then status=.InstrumentationFreshness~LATE
  else status=.InstrumentationFreshness~STALE
  return self~assessmentResult(status,"OK",age,evidence,freshWithinSeconds,staleAfterSeconds)

/* Pure value builder. Deliberately message-visible: ooRexx private methods do not
 * cross Message activity boundaries safely, and this class may be embedded in
 * asynchronous read-side consumers. It grants no mutation authority. */
::method assessmentResult
  use strict arg status,code,age,evidence,freshWithinSeconds,staleAfterSeconds
  d=.directory~new
  d["status"]=status
  d["code"]=code
  if age<>.nil then d["age_seconds"]=age
  d["fresh_within_seconds"]=freshWithinSeconds
  d["stale_after_seconds"]=staleAfterSeconds
  if evidence<>.nil then d["publication"]=.InstrumentationCodec~copyDirectory(evidence)
  return d

::requires "InstrumentationMesh.cls"
