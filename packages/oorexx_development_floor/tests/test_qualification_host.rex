failures = 0
catalog = .DFRegistrationCatalog~fromJsonFile("config/default_registrations.json")
k = catalog~hosts~at("ed209k")
call check k <> .nil, "Kilo registered"
call check k~qualificationEligible, "Kilo explicit qualification eligible"
call check \k~allocatable, "Kilo remains outside normal allocator pool"
call check k~capability("qemu") = "OBSERVED_PRESENT", "Kilo QEMU executable observed"
call check k~metadata["qualification_target"] = "REXXOS_QEMU_HELLO_DEPLOY", "Kilo qualification purpose pinned"
manager = .DFDevelopmentManager~new
manager~loadRegistrations("config/default_registrations.json")
selected = manager~selectQualificationHost("ed209k")
call check selected~id = "ed209k", "manager can select Kilo explicitly"
if failures = 0 then do
  say "PASS test_qualification_host"
  exit 0
end
say "FAIL test_qualification_host failures=" failures
exit 1

check: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "FAIL" label
  return

::requires "DevelopmentFloor.cls"
