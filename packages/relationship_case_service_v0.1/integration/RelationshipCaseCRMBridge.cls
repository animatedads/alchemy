/*
 * Theoretical CRM boundary for the initial model.
 *
 * This does not implement a CRM. It defines how a CRM-owned record becomes a
 * typed case reference while the source CRM retains authoritative content.
 */
::class RelationshipCRMReference public
::attribute crmSystem get
::attribute recordType get
::attribute recordId get
::attribute semanticKind get
::attribute authorityClass get
::attribute visibilityClass get
::method init
  expose crmSystem recordType recordId semanticKind authorityClass visibilityClass
  use arg crmSystemArg, recordTypeArg, recordIdArg, semanticKindArg = "CRM_RECORD", authorityClassArg = "CRM_REFERENCE", visibilityArg = "INTERNAL"
  crmSystem = .RelationshipCaseCanonical~token(crmSystemArg)
  recordType = .RelationshipCaseCanonical~token(recordTypeArg)
  recordId = recordIdArg~string
  semanticKind = .RelationshipCaseCanonical~token(semanticKindArg)
  authorityClass = .RelationshipCaseCanonical~token(authorityClassArg)
  visibilityClass = .RelationshipCaseCanonical~token(visibilityArg)
  if crmSystem = "" | recordType = "" | recordId = "" then raise syntax 88.940 array("CRM reference identity required")
::method sourceRef
  expose recordType recordId
  return recordType || ":" || recordId

::class RelationshipCaseCRMBridge public
::method elementFor class
  use arg elementId, elementType, relationship, crmReference, recordedAt = .nil
  if crmReference == .nil | \crmReference~isA(.RelationshipCRMReference) then return .RelationshipCaseResult~failure("CRM_REFERENCE_REQUIRED")
  if recordedAt == .nil then recordedAt = .DateTime~new
  element = .RelationshipCaseElement~new(elementId, elementType, crmReference~semanticKind, relationship, crmReference~crmSystem, crmReference~sourceRef, crmReference~authorityClass, recordedAt, crmReference~visibilityClass)~seal
  return .RelationshipCaseResult~success(element)
::method subject class
  use arg elementId, crmReference, recordedAt = .nil
  return self~elementFor(elementId, "SUBJECT", "SUBJECT_OF", crmReference, recordedAt)
::method interaction class
  use arg elementId, crmReference, recordedAt = .nil
  return self~elementFor(elementId, "INTERACTION", "ORIGINATING_INTERACTION", crmReference, recordedAt)
::method communication class
  use arg elementId, crmReference, recordedAt = .nil
  return self~elementFor(elementId, "COMMUNICATION", "CUSTOMER_COMMUNICATION", crmReference, recordedAt)
::method complaint class
  use arg elementId, crmReference, recordedAt = .nil
  return self~elementFor(elementId, "COMPLAINT", "CRM_COMPLAINT_RECORD", crmReference, recordedAt)
::method task class
  use arg elementId, crmReference, recordedAt = .nil
  return self~elementFor(elementId, "TASK", "CRM_WORK_ITEM", crmReference, recordedAt)

::requires "RelationshipCase.cls"
