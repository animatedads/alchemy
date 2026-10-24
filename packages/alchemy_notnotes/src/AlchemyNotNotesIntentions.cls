/* AlchemyNotNotesIntentions.cls
 * Provider-neutral Intention Service adapter for authoritative NotNotes work.
 * Recognition proposes canonical intentions; NotNotes remains the executor.
 */

::class AlchemyNotNotesIntentionRuntime public

::method init
  expose node service users authorities
  use strict arg newNode, newUsers = .nil, newAuthorities = .nil
  if newNode == .nil then raise syntax 93.900 array ("NotNotes intention runtime requires a node")
  node = newNode
  users = newUsers
  if users == .nil then users = .directory~new
  authorities = newAuthorities
  if authorities == .nil then authorities = .directory~new

  service = .IntentionService~new
  service~registerBucket("NOTNOTES_READ", .IntentionBucketPolicy~new("FLEXIBLE", 60, 12, .false, .true))
  service~registerBucket("NOTNOTES_WRITE", .IntentionBucketPolicy~new("EXPLICIT", 70, 12, .true, .false))

  spec = .directory~new
  spec~put(node, "NODE")
  spec~put(users, "USERS")
  sphere = service~registerSphere("NOTNOTES", spec, .AlchemyNotNotesDomainInterrogator~new)
  sphere~alias("NOTES")

  readMetadata = .directory~new
  readMetadata~put("NOTNOTES", "SPHERE")
  service~feed("NOTNOTES_READ", "Installed document definitions, semantic fields, views and current documents are authoritative application evidence.", -
      "notnotes-application-model", readMetadata)
  service~feed("NOTNOTES_WRITE", "NotNotes writes use domain operations, semantic field rules, feasibility assessment and explicit confirmation.", -
      "notnotes-operation-policy", readMetadata)

  registration = service~register("show documents", .AlchemyNotNotesQueryDocumentsEvent~new(node), "NOTNOTES_READ")
  registration~planBuilder(.AlchemyNotNotesQueryPlanBuilder~new)
  registration~planAssessor(.AlchemyNotNotesReadPlanAssessor~new(node))

  registration = service~register("show views", .AlchemyNotNotesListViewsEvent~new(node), "NOTNOTES_READ")
  registration~planBuilder(.AlchemyNotNotesListViewsPlanBuilder~new)
  registration~planAssessor(.AlchemyNotNotesReadPlanAssessor~new(node))

  registration = service~register("show fields", .AlchemyNotNotesListFieldsEvent~new(node), "NOTNOTES_READ")
  registration~requireSlot("DEFINITION_ID", "Which document definition?", .false)
  registration~planBuilder(.AlchemyNotNotesListFieldsPlanBuilder~new)
  registration~planAssessor(.AlchemyNotNotesFieldDescribePlanAssessor~new(node))

  registration = service~register("set field", .AlchemyNotNotesSetFieldEvent~new(node), "NOTNOTES_WRITE")
  registration~requireSlot("DOCUMENT_ID", "Which document should be changed?", .true)
  registration~requireSlot("FIELD_NAME", "Which field should be changed?", .true)
  registration~requireSlot("VALUE", "What value should be stored?", .true)
  registration~planBuilder(.AlchemyNotNotesSetFieldPlanBuilder~new)
  registration~planAssessor(.AlchemyNotNotesSetFieldPlanAssessor~new(node, authorities))

  registration = service~register("refer document", .AlchemyNotNotesReferDocumentEvent~new(node), "NOTNOTES_WRITE")
  registration~requireSlot("DOCUMENT_ID", "Which document should be referred?", .true)
  registration~requireSlot("TARGET_IDENTITY", "Who should receive the referral?", .true)
  registration~planBuilder(.AlchemyNotNotesReferralPlanBuilder~new)
  registration~planAssessor(.AlchemyNotNotesReferralPlanAssessor~new(node, users, authorities))

::method service
  expose service
  return service

::method input
  expose service
  use arg text
  return service~input(text)

::method dispatch
  expose service
  use arg decision
  assessment = decision~planAssessment
  if assessment \== .nil then do
    if assessment~status == "INFEASIBLE" then
      raise syntax 93.900 array ("NotNotes refuses to dispatch an infeasible intention plan")
  end
  return service~dispatch(decision)


::class AlchemyNotNotesDomainInterrogator public

::method interrogate
  use arg situation
  text = translate(strip(situation~body))
  spec = situation~spec
  node = spec~at("NODE")
  users = spec~at("USERS")
  proposals = .array~new

  if pos("REFER", text) > 0 then do
    proposal = self~referralProposal(node, users, text)
    if proposal \== .nil then proposals~append(proposal)
    return .IntentionInterrogationResult~new(proposals, "REFER", "NotNotes document/referral evidence")
  end

  if pos("SET ", text) > 0 then do
    proposal = self~setFieldProposal(node, text)
    if proposal \== .nil then proposals~append(proposal)
    return .IntentionInterrogationResult~new(proposals, "SET_FIELD", "NotNotes semantic field evidence")
  end

  if pos("FIELD", text) > 0 then do
    definition = self~definitionFromText(node, text)
    proposal = .IntentionProposal~new("SHOW_FIELDS", 96, "NOTNOTES_INTERROGATOR", .true, "field metadata request")
    if definition \== .nil then proposal~putSlot("DEFINITION_ID", definition~identity, .true)
    proposals~append(proposal)
    return .IntentionInterrogationResult~new(proposals, "DESCRIBE_FIELDS", "installed document-definition evidence")
  end

  if pos("VIEW", text) > 0 then do
    proposals~append(.IntentionProposal~new("SHOW_VIEWS", 97, "NOTNOTES_INTERROGATOR", .true, "view catalogue request"))
    return .IntentionInterrogationResult~new(proposals, "LIST_VIEWS", "installed view-definition evidence")
  end

  definition = self~definitionFromText(node, text)
  if definition \== .nil then do
    proposal = .IntentionProposal~new("SHOW_DOCUMENTS", 95, "NOTNOTES_INTERROGATOR", .true, "document-type request")
    proposal~putSlot("DEFINITION_ID", definition~identity, .true)
    proposals~append(proposal)
    return .IntentionInterrogationResult~new(proposals, "QUERY_DOCUMENTS", "installed document-definition evidence")
  end

  return .IntentionInterrogationResult~new(proposals, "UNKNOWN", "no authoritative NotNotes purpose evidence")

::method definitionFromText
  use arg node, text
  ids = node~documentDefinitionIds
  do identity over ids
    definition = node~documentDefinition(identity)
    name = translate(definition~name)
    form = translate(definition~formName)
    if pos(name, text) > 0 then return definition
    if pos(form, text) > 0 then return definition
    if name~right(1) \== "S" then do
      if pos(name || "S", text) > 0 then return definition
    end
    if name == "SALES ORDER" then do
      if pos("ORDERS", text) > 0 then return definition
      if pos("ORDER", text) > 0 then return definition
    end
  end
  return .nil

::method referralProposal
  use arg node, users, text
  document = self~documentFromText(node, text)
  target = self~userFromText(users, text)
  if document == .nil then do
    if target == .nil then return .nil
  end
  proposal = .IntentionProposal~new("REFER_DOCUMENT", 98, "NOTNOTES_INTERROGATOR", .true, "explicit referral request")
  if document \== .nil then proposal~putSlot("DOCUMENT_ID", document~documentId, .true)
  if target \== .nil then proposal~putSlot("TARGET_IDENTITY", target~identity, .true)
  proposal~putSlot("REASON", "Intention Service referral", .false)
  return proposal

::method setFieldProposal
  use arg node, text
  document = self~documentFromText(node, text)
  if document == .nil then return .nil
  definition = node~documentDefinition(document~definitionIdentity)
  if definition == .nil then return .nil
  marker = " TO "
  p = pos(marker, text)
  if p = 0 then return .nil
  targetText = strip(substr(text, 1, p - 1))
  field = self~fieldFromText(definition, targetText)
  if field == .nil then return .nil
  value = strip(substr(text, p + marker~length))
  onPosition = pos(" ON ", value)
  if onPosition > 0 then value = strip(substr(value, 1, onPosition - 1))
  if value == "" then return .nil
  proposal = .IntentionProposal~new("SET_FIELD", 98, "NOTNOTES_INTERROGATOR", .true, "explicit semantic field mutation")
  proposal~putSlot("DOCUMENT_ID", document~documentId, .true)
  proposal~putSlot("FIELD_NAME", field~name, .true)
  proposal~putSlot("VALUE", value, .true)
  return proposal

::method fieldFromText
  use arg definition, text
  do fieldName over definition~fieldNames
    field = definition~fieldDefinition(fieldName)
    if pos(field~name, text) > 0 then return field
    do alias over field~aliases
      if pos(alias, text) > 0 then return field
    end
  end
  return .nil

::method documentFromText
  use arg node, text
  documents = node~documents
  do document over documents
    fields = document~fieldNames
    do fieldName over fields
      value = document~field(fieldName)
      if value == .nil then iterate
      if value~isA(.AlchemyNotNotesDocumentReference) then iterate
      valueText = translate(value~string)
      if valueText \== "" then do
        if pos(valueText, text) > 0 then return document
      end
    end
  end
  return .nil

::method userFromText
  use arg users, text
  if users == .nil then return .nil
  supplier = users~supplier
  do while supplier~available
    user = supplier~item
    if user \== .nil then do
      if pos(translate(user~identity), text) > 0 then return user
      if pos(translate(user~displayName), text) > 0 then return user
    end
    supplier~next
  end
  return .nil


::class AlchemyNotNotesQueryPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Query authoritative NotNotes documents")
  plan~sideEffectClass = "READ_ONLY"
  definition = proposal~slot("DEFINITION_ID")
  if definition \== .nil then do
    args = .directory~new
    args~put(definition~value, "DEFINITION_ID")
    plan~addStep("QUERY_DOCUMENTS", "Select local documents by installed definition", "NOTNOTES", args)
  end
  else plan~addStep("QUERY_DOCUMENTS", "Select local documents", "NOTNOTES")
  plan~expectOutput("DOCUMENTS")
  return plan

::class AlchemyNotNotesListViewsPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "List installed NotNotes views")
  plan~sideEffectClass = "READ_ONLY"
  plan~addStep("LIST_VIEWS", "Read installed view-definition identities", "NOTNOTES")
  plan~expectOutput("VIEW_DEFINITIONS")
  return plan

::class AlchemyNotNotesListFieldsPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Describe semantic fields from an installed NotNotes document definition")
  plan~sideEffectClass = "READ_ONLY"
  plan~requireBinding("DEFINITION_ID")
  plan~addStep("DESCRIBE_FIELDS", "Read immutable semantic field-definition metadata", "NOTNOTES")
  plan~expectOutput("FIELD_DEFINITIONS")
  return plan

::class AlchemyNotNotesSetFieldPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Set one intention-writable NotNotes field")
  plan~sideEffectClass = "WRITE"
  plan~requireBinding("DOCUMENT_ID")
  plan~requireBinding("FIELD_NAME")
  plan~requireBinding("VALUE")
  plan~requireAuthority("NOTNOTES_FIELD_WRITE")
  plan~addStep("RESOLVE_DOCUMENT", "Use canonical NotNotes document identity", "NOTNOTES")
  plan~addStep("VALIDATE_FIELD_CAPABILITY", "Check semantic field mutation contract", "NOTNOTES")
  plan~addStep("SET_FIELD", "Apply ordinary field mutation", "NOTNOTES")
  plan~addStep("SAVE_REVISION", "Commit a new authoritative document revision", "NOTNOTES")
  plan~expectOutput("DOCUMENT")
  return plan

::class AlchemyNotNotesReferralPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Create a durable NotNotes referral")
  plan~sideEffectClass = "WRITE"
  plan~requireBinding("DOCUMENT_ID")
  plan~requireBinding("TARGET_IDENTITY")
  plan~requireAuthority("NOTNOTES_REFERRAL_CREATE")
  plan~addStep("RESOLVE_DOCUMENT", "Use canonical NotNotes document identity", "NOTNOTES")
  plan~addStep("CREATE_REFERRAL", "Create referral evidence on the document", "NOTNOTES")
  plan~addStep("SAVE_REVISION", "Commit a new authoritative document revision", "NOTNOTES")
  plan~expectOutput("REFERRAL_ITEM")
  return plan


::class AlchemyNotNotesReadPlanAssessor public
::method init
  expose node
  use arg newNode
  node = newNode
::method assess
  expose node
  use arg service, registration, proposal, plan, assessment
  if node == .nil then assessment~addUnavailableResource("NOTNOTES_NODE")
  if assessment~blockerCount = 0 then do
    assessment~markFeasible("Authoritative NotNotes node is available for read-only work.")
    assessment~addEvidence("installed NotNotes application model")
  end
  return assessment

::class AlchemyNotNotesFieldDescribePlanAssessor public
::method init
  expose node
  use arg newNode
  node = newNode
::method assess
  expose node
  use arg service, registration, proposal, plan, assessment
  if node == .nil then assessment~addUnavailableResource("NOTNOTES_NODE")
  definitionSlot = proposal~slot("DEFINITION_ID")
  if definitionSlot \== .nil then do
    if node~documentDefinition(definitionSlot~value) == .nil then assessment~addUnavailableResource("DOCUMENT_DEFINITION:" || definitionSlot~value)
  end
  if assessment~blockerCount = 0 then do
    assessment~markFeasible("Installed document definition can expose semantic field metadata.")
    assessment~addEvidence("document definition registry")
  end
  return assessment

::class AlchemyNotNotesSetFieldPlanAssessor public
::method init
  expose node authorities
  use arg newNode, newAuthorities
  node = newNode
  authorities = newAuthorities
::method assess
  expose node authorities
  use arg service, registration, proposal, plan, assessment
  documentSlot = proposal~slot("DOCUMENT_ID")
  fieldSlot = proposal~slot("FIELD_NAME")
  if documentSlot \== .nil then do
    document = node~document(documentSlot~value)
    if document == .nil then assessment~addUnavailableResource("DOCUMENT:" || documentSlot~value)
    else do
      definition = node~documentDefinition(document~definitionIdentity)
      if definition == .nil then assessment~addUnavailableResource("DOCUMENT_DEFINITION:" || document~definitionIdentity)
      else do
        if fieldSlot \== .nil then do
          field = definition~fieldDefinition(fieldSlot~value)
          if field == .nil then assessment~addUnavailableResource("FIELD:" || fieldSlot~value)
          else do
            if field~computed then assessment~addViolatedPrecondition("FIELD_COMPUTED:" || field~name)
            if \field~intentionWritable then assessment~addViolatedPrecondition("FIELD_NOT_INTENTION_WRITABLE:" || field~name)
            if field~processOwner \== "" then assessment~addViolatedPrecondition("FIELD_OWNED_BY:" || field~processOwner)
            assessment~addEvidence("field semantics " || definition~identity || "." || field~name)
          end
        end
      end
    end
  end
  if \self~hasAuthority("NOTNOTES_FIELD_WRITE") then assessment~addMissingAuthority("NOTNOTES_FIELD_WRITE")
  if assessment~blockerCount = 0 then assessment~markFeasible("Field exists and its semantic contract permits ordinary intention mutation.")
  return assessment
::method hasAuthority
  expose authorities
  use arg authority
  if authorities == .nil then return .false
  if authorities~hasIndex(authority) = 0 then return .false
  return authorities~at(authority) == .true

::class AlchemyNotNotesReferralPlanAssessor public
::method init
  expose node users authorities
  use arg newNode, newUsers, newAuthorities
  node = newNode
  users = newUsers
  authorities = newAuthorities
::method assess
  expose node users authorities
  use arg service, registration, proposal, plan, assessment
  documentSlot = proposal~slot("DOCUMENT_ID")
  targetSlot = proposal~slot("TARGET_IDENTITY")
  if documentSlot \== .nil then do
    if node~document(documentSlot~value) == .nil then assessment~addUnavailableResource("DOCUMENT:" || documentSlot~value)
  end
  if targetSlot \== .nil then do
    if users~hasIndex(targetSlot~value) = 0 then assessment~addUnavailableResource("RECIPIENT:" || targetSlot~value)
  end
  if authorities~hasIndex("NOTNOTES_REFERRAL_CREATE") = 0 then assessment~addMissingAuthority("NOTNOTES_REFERRAL_CREATE")
  else do
    if authorities~at("NOTNOTES_REFERRAL_CREATE") \== .true then assessment~addMissingAuthority("NOTNOTES_REFERRAL_CREATE")
  end
  if assessment~blockerCount = 0 then do
    assessment~markFeasible("Referral document, recipient and required authority are available.")
    assessment~addEvidence("NotNotes document store and identity directory")
  end
  return assessment


::class AlchemyNotNotesQueryDocumentsEvent public
::method init
  expose node
  use arg newNode
  node = newNode
::method invoke
  expose node
  use arg decision
  definitionSlot = decision~slots~at("DEFINITION_ID")
  if definitionSlot == .nil then return node~documents
  definition = node~documentDefinition(definitionSlot~value)
  if definition == .nil then return .array~new
  return node~documents(.Document~type(definition~formName))

::class AlchemyNotNotesListViewsEvent public
::method init
  expose node
  use arg newNode
  node = newNode
::method invoke
  expose node
  use arg decision
  return node~viewDefinitionIds

::class AlchemyNotNotesListFieldsEvent public
::method init
  expose node
  use arg newNode
  node = newNode
::method invoke
  expose node
  use arg decision
  definitionSlot = decision~slots~at("DEFINITION_ID")
  if definitionSlot == .nil then return .array~new
  definition = node~documentDefinition(definitionSlot~value)
  if definition == .nil then return .array~new
  fields = .array~new
  do fieldName over definition~fieldNames
    fields~append(definition~fieldDefinition(fieldName))
  end
  return fields

::class AlchemyNotNotesSetFieldEvent public
::method init
  expose node
  use arg newNode
  node = newNode
::method invoke
  expose node
  use arg decision
  documentSlot = decision~slots~at("DOCUMENT_ID")
  fieldSlot = decision~slots~at("FIELD_NAME")
  valueSlot = decision~slots~at("VALUE")
  if documentSlot == .nil then raise syntax 93.900 array ("field mutation requires canonical document identity")
  if fieldSlot == .nil then raise syntax 93.900 array ("field mutation requires canonical field name")
  if valueSlot == .nil then raise syntax 93.900 array ("field mutation requires a value")
  document = node~document(documentSlot~value)
  if document == .nil then raise syntax 93.900 array ("field mutation document is not present locally")
  document~putField(fieldSlot~value, valueSlot~value)
  node~save(document)
  return document

::class AlchemyNotNotesReferDocumentEvent public
::method init
  expose node
  use arg newNode
  node = newNode
::method invoke
  expose node
  use arg decision
  documentSlot = decision~slots~at("DOCUMENT_ID")
  targetSlot = decision~slots~at("TARGET_IDENTITY")
  if documentSlot == .nil then raise syntax 93.900 array ("referral dispatch requires canonical document identity")
  if targetSlot == .nil then raise syntax 93.900 array ("referral dispatch requires canonical target identity")
  document = node~document(documentSlot~value)
  if document == .nil then raise syntax 93.900 array ("referral document is not present locally")
  reason = "Intention Service referral"
  reasonSlot = decision~slots~at("REASON")
  if reasonSlot \== .nil then reason = reasonSlot~value
  referral = document~refer(targetSlot~value, reason)
  node~save(document)
  return referral


::requires "AlchemyNotNotes.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
