/* Minimal public-contract doubles for Intention Service v0.1-dev11 discovery. */

::class IntentionDiscoverySnapshot public
::attribute providerId get
::attribute generation get
::attribute surfaceAdvertisements get
::method init
  expose providerId generation surfaceAdvertisements
  use strict arg providerId, generation
  surfaceAdvertisements = .array~new
::method addSurfaceAdvertisement
  expose surfaceAdvertisements
  use strict arg advertisement
  surfaceAdvertisements~append(advertisement)
  return self

::class IntentionSurfaceAdvertisement public
::attribute id get
::attribute provider get
::attribute subject get
::attribute availability get
::attribute scope get
::attribute source get
::attribute effectClass get
::method init
  expose id provider subject availability scope source effectClass
  use strict arg id, provider, subject, availability, scope, source, effectClass

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
