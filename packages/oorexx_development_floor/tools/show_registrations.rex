/* Display deterministic Development Floor registration counts and key bindings. */
parse arg path
if path = "" then path = "config/default_registrations.json"
rawStream = .stream~new(path)
rawStream~open("READ")
rawText = rawStream~charIn(, rawStream~chars)
rawStream~close
raw = .json~fromJson(rawText)
catalog = .DFRegistrationCatalog~fromJsonFile(path)
say "REGISTRATIONS schema=" raw["schema"]
say "bots=" catalog~bots~all~items
say "control_planes=" catalog~controlPlanes~all~items
say "provider_accounts=" catalog~providerAccounts~all~items
say "execution_providers=" catalog~executionProviders~all~items
say "resource_providers=" catalog~resourceProviders~all~items
say "deployment_providers=" catalog~deploymentProviders~all~items
say "appliance_profiles=" catalog~applianceProfiles~all~items
say "hosts=" catalog~hosts~all~items
say "allocatable_hosts=" catalog~hosts~allocatable~items
cloud = catalog~controlPlanes~at("alchemy-cloud-control")
if cloud <> .nil then say "cloud_control_api=" cloud~api "status=" cloud~status
host = catalog~resourceProviders~at("ed209-host-resource")
if host <> .nil then say "ed209_surface=" host~operationSurface "transport=" host~metadata["underlying_transport"]
nodeProjection = catalog~resourceProviders~at("node-observation-projection")
if nodeProjection <> .nil then say "node_projection=" nodeProjection~operationSurface "status=" nodeProjection~status
firewall = catalog~resourceProviders~at("firewall-projection")
if firewall <> .nil then say "firewall_projection=" firewall~operationSurface "surface=" firewall~metadata["normal_surface"]
rexxos = catalog~deploymentProviders~at("rexxos-test-appliance")
if rexxos <> .nil then say "rexxos_mode=" rexxos~deploymentMode "default_profile=" rexxos~metadata["default_appliance_profile"] "boundary=" rexxos~metadata["verified_state_boundary"]
fast = catalog~applianceProfiles~at("REXXOS_FAST")
if fast <> .nil then say "rexxos_fast_status=" fast~status "provider=" fast~cryptoProvider "foreign_runtime=" fast~foreignRuntime "private_key_capability=" fast~privateKeyCapability
exit 0
::requires "Registrations.cls"
::requires "json.cls"
