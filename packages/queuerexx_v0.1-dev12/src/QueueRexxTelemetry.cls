/* QueueRexxTelemetry.cls - standardized provider health telemetry, v0.1-dev10.
 *
 * Telemetry is a read model.  It never owns queue lifecycle, placement, WLU,
 * migration, or runner authority.  Providers expose a common health report so
 * monitoring does not grow provider-specific if/case trees.
 */

::class QueueProviderTelemetrySnapshot public
::attribute directory get
::method init
  expose directory
  use strict arg directoryArg
  directory = directoryArg
::method asDirectory
  expose directory
  return directory

::class QueueProviderTelemetryCollector public
::attribute registry get
::attribute platformFacts get
::method init
  expose registry platformFacts
  use arg registryArg = .nil, platformFactsArg = .nil
  if registryArg == .nil then registry = .QueueProviderRegistry~builtins; else registry = registryArg
  if platformFactsArg == .nil then platformFacts = .QueuePlatformFacts~probeLocal; else platformFacts = platformFactsArg

::method collect
  expose registry platformFacts
  use arg categoryArg = .nil
  if categoryArg == .nil then categories = .QueueProviderCategory~values
  else categories = .Array~of(categoryArg~string~lower)
  rows = .Array~new
  overall = .QueueProviderHealthState~HEALTHY
  overallSeverity = .QueueProviderHealthState~severity(overall)
  do category over categories
    do provider over registry~all(category)
      if provider~hasMethod("HEALTH") then report = provider~health(platformFacts)
      else report = .QueueProviderHealthReport~new(category, provider~id, provider~version, .QueueProviderHealthState~UNKNOWN, "HEALTH_NOT_IMPLEMENTED", "provider has no standardized health probe", provider~capabilities)
      rows~append(report~asDirectory)
      severity = .QueueProviderHealthState~severity(report~state)
      if severity > overallSeverity then do
        overall = report~state
        overallSeverity = severity
      end
    end
  end
  d = .Directory~new
  d["schema"] = .QueueSchema~PROVIDER_HEALTH
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["captured_at"] = .DateTime~new~string
  d["overall_state"] = .QueueProviderHealthState~name(overall)
  d["overall_state_code"] = overall
  d["provider_count"] = rows~items
  d["providers"] = rows
  d["platform_facts"] = platformFacts~asDirectory
  d["authority_note"] = "provider telemetry is observational; provider and queue authorities remain separate"
  return .QueueProviderTelemetrySnapshot~new(d)

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
