parse arg registryPath
if registryPath = "" then registryPath = "state/specialist_registry.json"
registry = .DFQualifiedSpecialistRegistry~fromRegistryFile(registryPath)
call assertEqual 113, registry~count, "logical specialist count"
call assertEqual 127, registry~revisionCount, "specialist revision count"

odoo = registry~current("oorexx-odoo-crm-provider-specialist")
call assertTrue odoo <> .nil, "Odoo specialist present"
call assertEqual "oorexx_odoo_crm_provider_v0.1-dev7.1", odoo~packageId, "Odoo current revision"
call assertEqual 10, odoo~domainRules~items, "Odoo durable domain rules"
call assertEqual 6, registry~revisionsFor("oorexx-odoo-crm-provider-specialist")~items, "Odoo revision history"

manager = .DFDevelopmentManager~new
imported = manager~importQualifiedSpecialists(registry)
call assertEqual 113, imported, "manager imports logical specialists"
call assertEqual 113, manager~specialists~items, "manager specialist count"

say "PASS test_specialist_registry logical=" registry~count "revisions=" registry~revisionCount
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

::requires "SpecialistBootstrap.cls"
