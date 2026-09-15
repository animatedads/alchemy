if .FederationBankStaffWireUIApplicationBuild~VERSION <> "0.1" then do; say "FAIL app version"; exit 1; end
if .FederationBankStaffWireUIApplicationBuild~API_VERSION <> "federationbank.staff.wire-ui/0.1" then do; say "FAIL app api"; exit 1; end
if .FederationBankStaffWireWebGatewayBuild~VERSION <> "0.1" then do; say "FAIL gateway version"; exit 1; end
if .FederationBankStaffWireUIRuntimeModule~version <> "0.1" then do; say "FAIL runtime version"; exit 1; end
if .FederationBankStaffWireUIRuntimeModule~apiVersion <> "federationbank.staff.wire-ui/0.1" then do; say "FAIL runtime api"; exit 1; end
caps=.FederationBankStaffWireUIRuntimeModule~capabilities
if caps~items < 8 then do; say "FAIL runtime capabilities"; exit 1; end
say "PASS Staff Wire runtime/gateway surface compiles and reports v0.1"
exit 0
::requires "FederationBankStaffWireUIApplication.cls"
::requires "FederationBankStaffWireWebGatewayService.cls"
::requires "FederationBankStaffWireUIRuntimeModule.cls"
