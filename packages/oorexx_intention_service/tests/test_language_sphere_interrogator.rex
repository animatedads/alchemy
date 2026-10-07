/* Language/domain sphere interrogation and purpose evidence. */
log = .SphereLogService~new
service = .IntentionService~new
service~logger(log)
service~registerBucket("DATABASE", .IntentionBucketPolicy~new("FLEXIBLE", 1, 0, .false, .false))
service~register("show records", .nil, "DATABASE")
service~register("edit records", .nil, "DATABASE")

metadata = .Directory~new
metadata~put("DATABASE", "SPHERE")
service~feed("DATABASE", "SELECT displays rows; EDITOR is a role and does not itself mean mutate records.", "database-language-spec", metadata)

spec = .Directory~new
spec~put("database", "LANGUAGE")
interrogator = .DatabasePurposeInterrogator~new
sphere = service~registerSphere("DATABASE", spec, interrogator)
sphere~alias("DB")

decision = service~input("from database show records with LLM as EDITOR")
call assertEq "READY", decision~status, "sphere decision ready"
call assertEq "SHOW_RECORDS", decision~registration~id, "purpose is display"
call assertEq "DATABASE_INTERROGATOR", decision~proposal~providerName, "interrogator source"
call assertTrue interrogator~sawRecords > 0, "interrogator received corpus records"
call assertTrue log~hasPoint("INTENTION.SPHERE.SELECT"), "sphere selection logged"
call assertTrue log~hasPoint("INTENTION.INTERROGATOR.START"), "interrogator start logged"
call assertTrue log~hasPoint("INTENTION.INTERROGATOR.EVIDENCE"), "purpose evidence logged"

/* An inferred destructive intention still cannot bypass explicit bucket policy. */
service2 = .IntentionService~new
service2~registerBucket("DANGER", .IntentionBucketPolicy~new("EXPLICIT", 1, 0, .false, .false))
service2~register("erase database", .nil, "DANGER")
service2~registerSphere("DATABASE", spec, .DangerPurposeInterrogator~new)
blocked = service2~input("from database clean it up")
call assertEq "CLARIFY", blocked~status, "inferred destructive intention requires explicit wording"

say "PASS test_language_sphere_interrogator"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertTrue: procedure
  use arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

::class DatabasePurposeInterrogator
::method init
  expose sawRecords
  sawRecords = 0
::attribute sawRecords get
::method interrogate
  expose sawRecords
  use arg situation
  sawRecords = situation~records~items
  proposals = .Array~new
  proposals~append(.IntentionProposal~new("SHOW_RECORDS", 97, "DATABASE_INTERROGATOR", .false, "purpose=DISPLAY;role=EDITOR"))
  return .IntentionInterrogationResult~new(proposals, "DISPLAY", "records indicate show/display purpose")

::class DangerPurposeInterrogator
::method interrogate
  use arg situation
  proposals = .Array~of(.IntentionProposal~new("ERASE_DATABASE", 99, "DATABASE_INTERROGATOR", .false, "purpose=ERASE inferred from situation"))
  return .IntentionInterrogationResult~new(proposals, "ERASE", "inferred only")

::class SphereLogService
::method init
  expose events
  events = .Array~new
::method log
  expose events
  use arg level, payload, point
  row = .Directory~new
  row~put(point, "POINT")
  row~put(payload, "PAYLOAD")
  events~append(row)
::method hasPoint
  expose events
  use arg wanted
  do i = 1 to events~items
    if events~at(i)~at("POINT") == wanted then return .true
  end
  return .false

::requires "IntentionService.cls"
