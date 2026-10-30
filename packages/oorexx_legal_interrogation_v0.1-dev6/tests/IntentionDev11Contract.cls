/* Minimal public-contract doubles for Intention Service v0.1-dev11 discovery. */

::class FakeDev11IntentionService public
::attribute providers get
::method init
  expose providers
  providers = .array~new
::method registerDiscoveryProvider
  expose providers
  use strict arg provider
  providers~append(provider)
  return self
::method refreshDiscovery
  expose providers
  snapshots = .array~new
  do provider over providers
    snapshot = provider~discover(self)
    if snapshot \== .nil then snapshots~append(snapshot)
  end
  return snapshots

::class FakeNoDiscoveryIntentionService public
::method version
  return "0.1-dev10"

::class FakeIntentionDecision public
::attribute status get
::method init
  expose status
  use strict arg status
  status = status~upper
