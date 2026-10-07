catalog = .DFRegistrationCatalog~fromJsonFile("config/default_registrations.json")
call assertEqual 11, catalog~bots~all~items, "bot count"
call assertEqual 1, catalog~controlPlanes~all~items, "control plane count"
call assertEqual 7, catalog~providerAccounts~all~items, "provider account count"
call assertEqual 5, catalog~executionProviders~all~items, "execution provider count"
call assertEqual 11, catalog~resourceProviders~all~items, "resource provider count"
wluProvider = catalog~resourceProviders~at("wlu-authority")
call assertEqual "QUALIFIED_EXECUTABLE_ADAPTER", wluProvider~status, "WLU executable adapter registered"
call assertEqual 1, wluProvider~metadata["mandatory_for_substantive_assignment_execution"], "WLU mandatory execution boundary"
accountingProvider = catalog~resourceProviders~at("development-floor-accounting-ledger")
call assertEqual "QUALIFIED_DURABLE_NON_ENTITLING", accountingProvider~status, "accounting ledger registered"
call assertEqual 0, accountingProvider~metadata["can_grant_work"], "accounting ledger cannot grant work"
call assertEqual 2, catalog~deploymentProviders~all~items, "deployment provider count"
call assertEqual 3, catalog~applianceProfiles~all~items, "appliance profile count"
call assertEqual 10, catalog~hosts~all~items, "host registration count"
call assertEqual 5, catalog~hosts~allocatable~items, "currently allocatable host count"

managerBot = catalog~bots~at("development-manager")
call assertTrue managerBot <> .nil, "development manager registered"
call assertTrue managerBot~hasCapability("allocate_work"), "manager allocation capability"
call assertTrue managerBot~hasCapability("select_control_plane"), "manager control-plane selection capability"
infraBot = catalog~bots~at("cloud-infrastructure-specialist")
call assertTrue infraBot~hasCapability("request_cloud_control"), "infrastructure specialist cloud-control capability"
call assertEqual 1, infraBot~constraint("raw_ssh_forbidden"), "infrastructure specialist cannot bypass sshnode"


observerBot = catalog~bots~at("infrastructure-observer")
call assertTrue observerBot~hasCapability("refresh_node_projection"), "infrastructure observer node projection"
call assertTrue observerBot~hasCapability("refresh_firewall_projection"), "infrastructure observer firewall projection"
call assertEqual 1, observerBot~constraint("read_only"), "infrastructure observer is read-only"

cloud = catalog~controlPlanes~at("alchemy-cloud-control")
call assertTrue cloud <> .nil, "Alchemy Cloud Control registered"
call assertEqual "alchemy.cloud-control/0.1", cloud~api, "cloud control API"
call assertTrue cloud~hasKind("SERVICE"), "cloud control service kind"
call assertTrue cloud~hasKind("RESOURCE"), "cloud control resource kind"
call assertTrue cloud~hasKind("NODE"), "cloud control node kind"
call assertEqual 1, cloud~metadata["exact_oorexx_r13196_regressions_passed"], "cloud control exact runtime qualification"
call assertEqual "alchemy_cloud_control_v0.1-dev2", cloud~metadata["package"], "cloud control dev2 dependency"
call assertEqual "0a29487b499b19c164ffc6af481b6e9feebade01ba152a96b3e7ae60e6e12bf2", cloud~metadata["package_sha256"], "cloud control final ZIP identity"
call assertEqual 0, cloud~metadata["live_cloud_mutation_qualified"], "no live mutation overclaim"

bashqueue = catalog~providerAccounts~at("gcp-bashqueue")
call assertEqual "GCP", bashqueue~provider, "bashqueue provider"
call assertEqual "bashqueue", bashqueue~selector, "bashqueue account selector"
call assertEqual "bashqueue@gmail.com", bashqueue~expectedIdentity, "bashqueue expected identity"
call assertEqual "GOOGLE_TRIAL_CREDIT", bashqueue~fundingSource, "bashqueue funding source"

animated = catalog~providerAccounts~at("gcp-animated-ads-cy")
call assertEqual "animated.ads.cy@gmail.com", animated~expectedIdentity, "animated ads expected identity"
call assertEqual "FREE_SERVICE_ENTITLEMENTS", animated~fundingSource, "animated ads current funding classification"

ed209c = catalog~hosts~at("ed209c")
call assertEqual "ACTIVE", ed209c~lifecycle, "ED209C active"
call assertEqual "QUALIFIED", ed209c~capability("qemu"), "ED209C QEMU evidence"
call assertEqual 1, ed209c~allocatable, "active ED209C allocatable"
call assertEqual "azure-free", ed209c~providerAccountId, "ED209C Azure account binding"

ed209j = catalog~hosts~at("ed209j")
call assertEqual "gcp-bashqueue", ed209j~providerAccountId, "ED209J provider account"
call assertEqual 1, ed209j~allocatable, "ED209J allocatable"

ed209k = catalog~hosts~at("ed209k")
call assertEqual "VULTR", ed209k~provider, "ED209K provider"
call assertEqual "vultr-free-1y", ed209k~providerAccountId, "ED209K provider account"
call assertEqual "UNKNOWN", ed209k~allocationStatus, "ED209K general allocation still pending"
call assertEqual "OBSERVED_PRESENT", ed209k~capability("qemu"), "ED209K QEMU executable observed"
call assertEqual "x86_64", ed209k~capability("architecture"), "ED209K architecture observed"
call assertEqual 0, ed209k~allocatable, "ED209K not generally allocatable"
call assertEqual 1, ed209k~qualificationEligible, "ED209K explicit qualification override"
call assertEqual 1, ed209k~metadata["smallest_machine"], "ED209K smallest-machine canary"

hostProvider = catalog~resourceProviders~at("ed209-host-resource")
call assertEqual "alchemy-cloud-control", hostProvider~controlPlaneId, "ED209 cloud control registration"
call assertEqual "alchemy.cloud-control/0.1:NODE", hostProvider~operationSurface, "ED209 normalized node surface"
call assertEqual "sshnode.sh", hostProvider~metadata["underlying_transport"], "ED209 exclusive underlying transport"

cloudResource = catalog~resourceProviders~at("cloud-resource-control")
call assertEqual "alchemy-cloud-control", cloudResource~controlPlaneId, "cloud resource control plane"
call assertEqual "alchemy.cloud-control/0.1:RESOURCE", cloudResource~operationSurface, "cloud normalized resource surface"

nodeProjection = catalog~resourceProviders~at("node-observation-projection")
call assertEqual "NODE_OBSERVATION", nodeProjection~resourceKind, "node projection resource kind"
call assertEqual 1, nodeProjection~metadata["retains_divergent_evidence"], "node projection preserves divergence"
firewallProjection = catalog~resourceProviders~at("firewall-projection")
call assertEqual "FIREWALL", firewallProjection~resourceKind, "firewall normalized resource kind"
call assertEqual "FIREWALL", firewallProjection~metadata["normal_surface"], "firewall normal surface"

network = catalog~resourceProviders~at("network-lease")
call assertEqual "REGISTERED_INCOMPLETE", network~status, "network lease not overclaimed"
call assertEqual 0, network~metadata["firewall_add_remove_available"], "firewall mutation still missing"

rexxos = catalog~deploymentProviders~at("rexxos-test-appliance")
call assertEqual "IMAGE_MATERIALISATION", rexxos~deploymentMode, "RexxOS image materialisation"
call assertEqual "sshnode.sh", rexxos~hostTransport, "RexxOS ultimate host transport"
call assertEqual "alchemy-cloud-control", rexxos~controlPlaneId, "RexxOS normalized control plane"
call assertEqual "REXXOS_FAST", rexxos~metadata["default_appliance_profile"], "RexxOS FAST default profile"
call assertEqual "STAGED", rexxos~metadata["verified_state_boundary"], "RexxOS staged boundary"

minimal = catalog~applianceProfiles~at("REXXOS_MINIMAL")
call assertEqual "QUALIFIED_FALLBACK", minimal~status, "MINIMAL qualified fallback"
call assertEqual "pure-rexx", minimal~cryptoProvider, "MINIMAL pure Rexx crypto"
call assertEqual 0, minimal~privateKeyCapability, "MINIMAL no private-key authority"

fast = catalog~applianceProfiles~at("REXXOS_FAST")
call assertEqual "QUALIFIED_DEFAULT", fast~status, "FAST qualified default"
call assertEqual "foreign.openssl.crypto", fast~cryptoProvider, "FAST crypto provider"
call assertEqual "0.22.6", fast~foreignRuntime, "FAST Foreign Runtime"
call assertEqual "OpenSSL", fast~nativeProvider, "FAST native provider"
call assertEqual 0, fast~privateKeyCapability, "FAST no private-key service authority"
call assertEqual "openssl.libcrypto.hybrid.v2", fast~metadata["crypto_implementation"], "FAST implementation evidence"
call assertEqual "/lib/x86_64-linux-gnu/libcrypto.so.3", fast~metadata["native_provider_path"], "FAST provider path evidence"

crypto = catalog~applianceProfiles~at("REXXOS_CRYPTO")
call assertEqual 1, crypto~privateKeyCapability, "CRYPTO private-key authority class"
call assertEqual "REGISTERED_UNQUALIFIED_PRIVATE_KEY_SERVICE", crypto~status, "CRYPTO not overqualified"
call assertEqual "REXXOS_FAST", catalog~applianceProfiles~qualifiedDefault("REXXOS_QEMU")~id, "FAST selected as qualified default"

activationBot = catalog~bots~at("rto-activation-specialist")
call assertEqual "REGISTERED", activationBot~status, "RTO activation specialist registered"
call assertEqual 1, activationBot~constraint("cannot_claim_active_from_staged"), "RTO activation does not skip lifecycle"

opus = catalog~executionProviders~at("google-claude-opus-5")
call assertEqual "PREMIUM_ESCALATION", opus~routingClass, "Opus premium routing"
call assertEqual "gcp-bashqueue", opus~providerAccountId, "Opus account binding"
call assertEqual 0, catalog~executionProviders~eligible("AGENTIC", "NORMAL")~items, "premium excluded from normal routing"
call assertTrue catalog~executionProviders~eligible("CODING", "PREMIUM_ESCALATION")~items >= 3, "coding providers available by premium ceiling"

manager = .DFDevelopmentManager~new
manager~loadRegistrations("config/default_registrations.json")
kilo = manager~selectQualificationHost("ed209k")
call assertEqual "ed209k", kilo~id, "manager explicitly selects Kilo qualification target"
call assertEqual 0, kilo~allocatable, "qualification override does not promote general allocation"
selectedProfile = manager~selectApplianceProfile("REXXOS_QEMU")
call assertEqual "REXXOS_FAST", selectedProfile~id, "manager chooses FAST default"
selectedMinimal = manager~selectApplianceProfile("REXXOS_QEMU", "REXXOS_MINIMAL")
call assertEqual "REXXOS_MINIMAL", selectedMinimal~id, "manager honors explicit MINIMAL fallback"
specialist = .DFSpecialistProfile~new("ODOO", "OODOO", "ooRexx")
manager~registerSpecialist(specialist)
assignment = .DFAssignment~new("A-BIND", "FRAMEWORK", "OODOO", "ooRexx", "bounded implementation")
manager~addAssignment(assignment)
assignment~assignTo("ODOO")
manager~bindAssignmentExecution("A-BIND", "coding-specialist", "azure-gpt-6-luna")
call assertEqual "ODOO", assignment~specialistId, "specialist identity retained"
call assertEqual "coding-specialist", assignment~botProfileId, "bot role bound independently"
call assertEqual "azure-gpt-6-luna", assignment~executionProviderId, "execution provider bound independently"

say "PASS test_registrations"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
assertTrue: procedure
  use arg value, label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return

::requires "DevelopmentFloor.cls"
