/* AlchemyNotNotes.cls
 * Minimal executable spine for an offline-first replicated document node.
 * Prototype scope: Directory-backed dynamic document fields, setMethod-backed
 * active document relationships, typed field sources, external document links,
 * node-local object/content stores, revision lineage, population/document replication,
 * relationship resolution, versioned document/view definitions, local view projection and conflict detection.
 */

::class AlchemyNotNotesDocument public subclass Directory

/* Initialise one durable document identity and form/type name. */
::method init
  expose documentId formName definitionIdentity links ownerNode revision revisionId lineage lastWriterNode installedLinkNames fieldDefinitions scriptHandlers
  use arg documentId, formName
  if documentId == .nil then raise syntax 93.900 array ("documentId must not be empty")
  if documentId~string~strip = "" then raise syntax 93.900 array ("documentId must not be empty")
  if formName == .nil then raise syntax 93.900 array ("formName must not be empty")
  if formName~string~strip = "" then raise syntax 93.900 array ("formName must not be empty")

  self~init:super
  self~put(.ApprovalSet~new, "APPROVALS")
  self~put(.ReferralSet~new, "REFERRALS")
  documentId = documentId~string
  formName = formName~string
  definitionIdentity = ""
  links = .directory~new
  installedLinkNames = .directory~new
  fieldDefinitions = .directory~new
  scriptHandlers = .directory~new
  ownerNode = .nil
  revision = 0
  revisionId = ""
  lineage = .array~new
  lastWriterNode = ""

/* Return the durable document identity. */
::method documentId
  expose documentId
  return documentId

/* Return the document form/type name. */
::method formName
  expose formName
  return formName

/* Return the exact document-definition identity bound at composition time. */
::method definitionIdentity
  expose definitionIdentity
  return definitionIdentity

/* Bind this instance to one exact immutable document-definition identity. */
::method bindDefinition
  expose definitionIdentity
  use arg newDefinitionIdentity
  if newDefinitionIdentity == .nil then raise syntax 93.900 array ("definition identity must not be empty")
  if newDefinitionIdentity~string~strip = "" then raise syntax 93.900 array ("definition identity must not be empty")
  if definitionIdentity <> "" then do
    if definitionIdentity <> newDefinitionIdentity~string then
      raise syntax 93.900 array ("document definition identity is already bound")
  end
  definitionIdentity = newDefinitionIdentity~string
  return self

/* Build a reusable document-type selector for linked-document queries. */
::method type class
  use arg formName
  return .AlchemyNotNotesDocumentType~new(formName)

/* Attach this document to its transient local node context. */
::method attachNode
  expose ownerNode
  use arg node
  ownerNode = node
  return self

/* Create one durable outgoing document relationship. */
::method linkDocument
  use strict arg otherDocument, linkName = ""
  if otherDocument == .nil then raise syntax 93.900 array ("linked document must not be .nil")
  if otherDocument~documentId = self~documentId then
    raise syntax 93.900 array ("a document cannot link to itself")

  self~addLink(otherDocument~documentId, linkName)
  return otherDocument

/* Return documents that link to this document, optionally filtered by type. */
::method linkedDocuments
  expose ownerNode documentId
  use strict arg typeFilter = .nil
  if ownerNode == .nil then return .array~new
  return ownerNode~linkedDocumentsTo(documentId, typeFilter)

/* Test whether this document has an outgoing link to another identity. */
::method linksTo
  expose links
  use arg documentId
  if documentId == .nil then return .false
  return links~hasIndex(documentId~string)

/* Return a named related document, or .nil when no local target resolves. */
::method relatedDocument
  expose links ownerNode
  use arg linkName
  if ownerNode == .nil then return .nil
  if linkName == .nil then return .nil
  wanted = linkName~string~upper

  indexes = links~allIndexes
  do documentId over indexes
    link = links~at(documentId)
    if link~name~upper <> wanted then iterate
    return ownerNode~document(documentId)
  end
  return .nil

/* Add or refresh one local link descriptor without committing a revision. */
::method addLink
  expose links
  use arg documentId, linkName
  if documentId == .nil then raise syntax 93.900 array ("linked document identity must not be empty")
  if linkName == .nil then linkName = ""
  links~put(.AlchemyNotNotesDocumentLink~new(documentId~string, linkName~string), documentId~string)
  self~installLinkResolver(linkName~string)
  return self

/* Define one first-class field and its value-source policy. */
::method defineField
  expose fieldDefinitions
  use strict arg fieldName, source = .nil
  key = self~normaliseFieldName(fieldName)
  field = .Field~new(key, source)
  fieldDefinitions~put(field, key)
  return field

/* Return a first-class field definition, or .nil when the field is untyped. */
::method fieldObject
  expose fieldDefinitions
  use arg fieldName
  key = self~normaliseFieldName(fieldName)
  return fieldDefinitions~at(key)

/* Install one exact script handler carried with this document revision. */
::method installScriptHandler
  expose scriptHandlers
  use arg handler
  if handler == .nil then raise syntax 93.900 array ("script handler must not be .nil")
  copy = handler~snapshotCopy
  scriptHandlers~put(copy, copy~eventName)
  return copy

/* Return one carried script handler by event name. */
::method scriptHandler
  expose scriptHandlers
  use arg eventName
  if eventName == .nil then return .nil
  return scriptHandlers~at(eventName~string~upper)

/* Return detached event names implemented by this document's script section. */
::method scriptEvents
  expose scriptHandlers
  events = .array~new
  names = scriptHandlers~allIndexes
  do eventName over names
    events~append(eventName)
  end
  return events

/* Record one first-class business approval result on this document. */
::method approval
  use strict arg name, outcome, signMode = "", evidence = .nil
  signed = .false
  if signMode \== .nil then signed = signMode~string~upper = "SIGN"
  return self~Approvals~evaluate(name, outcome, signed, evidence)

/* Create one first-class referral to a node-local identity when requested. */
::method refer
  use strict arg target, reason = "", when = .true
  if when \= .true then return .nil
  if target == .nil then raise syntax 93.900 array ("referral target must not be .nil")
  targetIdentity = target~string
  if target~isA(.AlchemyNotNotesUserIdentity) then targetIdentity = target~identity
  return self~Referrals~refer(targetIdentity, reason)

/* Derive presentation status from authoritative approval and referral evidence. */
::method approvalStatus
  approvals = self~Approvals
  referrals = self~Referrals
  if referrals~anyOpen then return "PENDING APPROVAL"
  if referrals~anyRejected then return "REJECTED"
  if approvals~items = 0 then do
    if referrals~allResolvedApproved then return "APPROVED"
    return "DRAFT"
  end
  if approvals~anyFailed then do
    if referrals~allResolvedApproved then return "APPROVED"
    return "PENDING APPROVAL"
  end
  return "APPROVED"

/* Bind an internal typed document reference through a first-class field. */
::method setReferenceField
  expose ownerNode
  use strict arg fieldName, reference
  if ownerNode == .nil then raise syntax 93.900 array ("document is not attached to a node")
  if reference == .nil then raise syntax 93.900 array ("reference must not be .nil")
  if \reference~isA(.AlchemyNotNotesDocumentReference) then
    raise syntax 93.900 array ("reference must be a DocumentReference")

  field = self~fieldObject(fieldName)
  if field == .nil then raise syntax 93.900 array ("reference field is not defined: " || fieldName)
  source = field~source
  if source == .nil then raise syntax 93.900 array ("reference field has no source: " || fieldName)

  target = reference~resolve(ownerNode)
  if target == .nil then raise syntax 93.900 array ("referenced document is not present on this node")
  if \source~acceptsDocument(target) then
    raise syntax 93.900 array ("referenced document does not satisfy field type")
  self~linkDocument(target, fieldName)
  return target

/* Store a link to an external document as an ordinary replicated field value. */
::method setExternalField
  use strict arg fieldName, externalLink
  if externalLink == .nil then raise syntax 93.900 array ("external document link must not be .nil")
  if \externalLink~isA(.AlchemyNotNotesExternalDocumentLink) then
    raise syntax 93.900 array ("value must be an ExternalDocumentLink")

  field = self~fieldObject(fieldName)
  if field == .nil then raise syntax 93.900 array ("external document field is not defined: " || fieldName)
  source = field~source
  if source == .nil then raise syntax 93.900 array ("external document field has no source: " || fieldName)
  if \source~acceptsLink(externalLink) then
    raise syntax 93.900 array ("external document does not satisfy field media type")
  self~putField(fieldName, externalLink)
  return externalLink

/* Return detached external-document links referenced by ordinary fields. */
::method externalDocumentLinks
  links = .array~new
  names = self~fieldNames
  do name over names
    value = self~at(name)
    if value == .nil then iterate
    if value~isA(.AlchemyNotNotesExternalDocumentLink) then
      links~append(value~snapshotCopy)
  end
  return links

/* Return the current local revision number. */
::method revision
  expose revision
  return revision

/* Return the globally distinguishable revision token. */
::method revisionId
  expose revisionId
  return revisionId

/* Return the node that authored the current revision. */
::method lastWriterNode
  expose lastWriterNode
  return lastWriterNode

/* Store or replace a dynamic document field in the Directory substrate. */
::method putField
  expose installedLinkNames
  use arg fieldName, value
  key = self~normaliseFieldName(fieldName)
  if installedLinkNames~hasIndex(key) then
    raise syntax 93.900 array ("field name conflicts with a named document relationship: " || key)
  self~put(value, key)
  return value

/* Fetch a dynamic document field by name. */
::method field
  expose installedLinkNames
  use arg fieldName
  key = self~normaliseFieldName(fieldName)
  if installedLinkNames~hasIndex(key) then return .nil
  if self~hasIndex(key) then return self~at(key)
  return .nil

/* Test whether a dynamic field exists. */
::method hasField
  expose installedLinkNames
  use arg fieldName
  key = self~normaliseFieldName(fieldName)
  if installedLinkNames~hasIndex(key) then return .false
  return self~hasIndex(key)

/* Return a detached list of data-field names, excluding active link members. */
::method fieldNames
  expose installedLinkNames
  names = .array~new
  indexes = self~allIndexes
  do name over indexes
    if installedLinkNames~hasIndex(name) then iterate
    names~append(name)
  end
  return names

/* Commit the current document state as a new revision authored by nodeId. */
::method commit
  expose documentId revision revisionId lineage lastWriterNode
  use arg nodeId
  if nodeId == .nil then raise syntax 93.900 array ("nodeId must not be empty")
  if nodeId~string~strip = "" then raise syntax 93.900 array ("nodeId must not be empty")

  if revision > 0 then lineage~append(revisionId)
  revision += 1
  lastWriterNode = nodeId~string
  revisionId = documentId || ":" || revision || ":" || lastWriterNode
  return revisionId

/* Produce a detached immutable-by-convention replication snapshot. */
::method snapshot
  expose documentId formName definitionIdentity links revision revisionId lineage lastWriterNode fieldDefinitions scriptHandlers
  fieldCopy = self~copyFields
  definitionCopy = self~copyFieldDefinitions(fieldDefinitions)
  handlerCopy = self~copyScriptHandlers(scriptHandlers)
  linkCopy = self~copyLinks(links)
  lineageCopy = self~copyArray(lineage)
  return .AlchemyNotNotesDocumentSnapshot~new(documentId, formName, definitionIdentity, fieldCopy, definitionCopy, handlerCopy, linkCopy, revision, revisionId, lineageCopy, lastWriterNode)

/* Replace this object's state from an accepted replication snapshot. */
::method loadSnapshot
  expose documentId formName definitionIdentity links revision revisionId lineage lastWriterNode fieldDefinitions scriptHandlers
  use arg snapshot
  if snapshot == .nil then raise syntax 93.900 array ("snapshot must not be .nil")
  if documentId <> snapshot~documentId then
    raise syntax 93.900 array ("snapshot document identity mismatch")

  self~clearDynamicMembers
  formName = snapshot~formName
  definitionIdentity = snapshot~definitionIdentity
  snapshotFields = snapshot~fields
  fieldIndexes = snapshotFields~allIndexes
  do fieldName over fieldIndexes
    self~put(snapshotFields~at(fieldName), fieldName)
  end
  fieldDefinitions = self~copyFieldDefinitions(snapshot~fieldDefinitions)
  scriptHandlers = self~copyScriptHandlers(snapshot~scriptHandlers)
  links = self~copyLinks(snapshot~links)
  self~rebuildLinkResolvers
  revision = snapshot~revision
  revisionId = snapshot~revisionId
  lineage = self~copyArray(snapshot~lineage)
  lastWriterNode = snapshot~lastWriterNode
  return self

/* Construct a new independent document object from a snapshot. */
::method fromSnapshot class
  use arg snapshot
  if snapshot == .nil then raise syntax 93.900 array ("snapshot must not be .nil")
  document = self~new(snapshot~documentId, snapshot~formName)
  document~loadSnapshot(snapshot)
  return document

/* Preserve Directory's dynamic member semantics while protecting relation names. */
::method unknown
  expose installedLinkNames
  use arg messageName, messageArguments
  upperName = messageName~string~upper
  if right(upperName, 1) = "=" then do
    fieldName = left(upperName, length(upperName) - 1)
    if installedLinkNames~hasIndex(fieldName) then
      raise syntax 93.900 array ("cannot assign a data field over named document relationship: " || fieldName)
  end
  forward class (super)

/* Install one Directory active member that resolves a named document link. */
::method installLinkResolver
  expose installedLinkNames
  use arg linkName
  if linkName == .nil then return self
  if linkName~string~strip = "" then return self
  key = linkName~string~upper
  if \installedLinkNames~hasIndex(key) then do
    if self~hasIndex(key) then
      raise syntax 93.900 array ("named document relationship conflicts with data field: " || key)
  end
  safeName = linkName~string~changestr("'", "''")
  source = .array~of("return self~relatedDocument('" || safeName || "')")
  self~setMethod(key, .method~new(key, source))
  installedLinkNames~put(.true, key)
  return self

/* Rebuild transient Directory active members from durable link descriptors. */
::method rebuildLinkResolvers
  expose links
  indexes = links~allIndexes
  do documentId over indexes
    link = links~at(documentId)
    self~installLinkResolver(link~name)
  end
  return self

/* Remove transient active members and ordinary Directory data entries. */
::method clearDynamicMembers
  expose installedLinkNames
  names = installedLinkNames~allIndexes
  do name over names
    self~unsetMethod(name)
  end
  installedLinkNames = .directory~new
  self~empty
  return self

/* Copy ordinary document fields without materialising active link members. */
::method copyFields
  copy = .directory~new
  names = self~fieldNames
  do name over names
    copy~put(self~copyFieldValue(self~at(name)), name)
  end
  return copy

/* Copy first-class field definitions independently for each replica. */
::method copyFieldDefinitions
  use arg source
  copy = .directory~new
  indexes = source~allIndexes
  do index over indexes
    copy~put(source~at(index)~snapshotCopy, index)
  end
  return copy

/* Copy known mutable/reference field values without sharing replica objects. */
::method copyFieldValue
  use arg value
  if value == .nil then return .nil
  if value~isA(.AlchemyNotNotesApprovalSet) then return value~snapshotCopy
  if value~isA(.AlchemyNotNotesReferralSet) then return value~snapshotCopy
  if value~isA(.AlchemyNotNotesExternalDocumentLink) then return value~snapshotCopy
  if value~isA(.AlchemyNotNotesDocumentReference) then return value~snapshotCopy
  if value~isA(.Array) then do
    copy = .array~new
    do item over value
      copy~append(self~copyFieldValue(item))
    end
    return copy
  end
  if value~isA(.Directory) then do
    copy = .directory~new
    indexes = value~allIndexes
    do index over indexes
      copy~put(self~copyFieldValue(value~at(index)), index)
    end
    return copy
  end
  return value

/* Canonicalise dynamic field names to ooRexx message-style upper case. */
::method normaliseFieldName
  use arg fieldName
  if fieldName == .nil then raise syntax 93.900 array ("field name must not be empty")
  if fieldName~string~strip = "" then raise syntax 93.900 array ("field name must not be empty")
  return fieldName~string~upper

/* Copy script handlers so replicated documents carry detached behaviour source. */
::method copyScriptHandlers
  use arg source
  copy = .directory~new
  indexes = source~allIndexes
  do eventName over indexes
    handler = source~at(eventName)
    copy~put(handler~snapshotCopy, eventName)
  end
  return copy

/* Copy link descriptors so replicas never share mutable link containers. */
::method copyLinks
  use arg source
  copy = .directory~new
  indexes = source~allIndexes
  do index over indexes
    link = source~at(index)
    copy~put(.AlchemyNotNotesDocumentLink~new(link~documentId, link~name), index)
  end
  return copy

/* Copy an array so revision ancestry is replica-local. */
::method copyArray
  use arg source
  copy = .array~new
  do item over source
    copy~append(item)
  end
  return copy


::class AlchemyNotNotesDocumentSnapshot public

/* Capture one detached document revision for replication. */
::method init
  expose documentId formName definitionIdentity fields fieldDefinitions scriptHandlers links revision revisionId lineage lastWriterNode
  use arg newDocumentId, newFormName, newDefinitionIdentity, newFields, newFieldDefinitions, newScriptHandlers, newLinks, newRevision, newRevisionId, newLineage, newLastWriterNode
  documentId = newDocumentId
  formName = newFormName
  definitionIdentity = newDefinitionIdentity
  fields = newFields
  fieldDefinitions = newFieldDefinitions
  scriptHandlers = newScriptHandlers
  links = newLinks
  revision = newRevision
  revisionId = newRevisionId
  lineage = newLineage
  lastWriterNode = newLastWriterNode

::attribute documentId get
::attribute formName get
::attribute definitionIdentity get
::attribute fields get
::attribute fieldDefinitions get
::attribute scriptHandlers get
::attribute links get
::attribute revision get
::attribute revisionId get
::attribute lineage get
::attribute lastWriterNode get

/* Test whether this revision descends from ancestorRevisionId. */
::method hasAncestor
  expose lineage
  use arg ancestorRevisionId
  if ancestorRevisionId == .nil then return .false
  if ancestorRevisionId = "" then return .false
  do item over lineage
    if item = ancestorRevisionId then return .true
  end
  return .false


::class AlchemyNotNotesDocumentLink public

/* Capture one durable document relationship edge. */
::method init
  expose documentId name
  use arg newDocumentId, newName
  documentId = newDocumentId
  name = newName

::attribute documentId get
::attribute name get


::class AlchemyNotNotesDocumentType public

/* Build a type selector used by linkedDocuments(). */
::method init
  expose formName
  use arg newFormName
  if newFormName == .nil then raise syntax 93.900 array ("document type must not be empty")
  if newFormName~string~strip = "" then raise syntax 93.900 array ("document type must not be empty")
  formName = newFormName~string

::attribute formName get

/* Test whether a candidate document has the selected form/type. */
::method matches
  expose formName
  use arg document
  if document == .nil then return .false
  return document~formName~upper = formName~upper



::class AlchemyNotNotesDocumentReference public

/* Capture one stable internal document reference without retaining object identity. */
::method init
  expose documentId formName
  use arg newDocumentId, newFormName
  documentId = newDocumentId~string
  formName = newFormName~string

::attribute documentId get
::attribute formName get

/* Resolve this reference against one node's local replica population. */
::method resolve
  expose documentId
  use arg node
  if node == .nil then return .nil
  return node~document(documentId)

/* Copy the reference so replicas never share the same reference object. */
::method snapshotCopy
  expose documentId formName
  return .DocumentReference~new(documentId, formName)


::class DocumentReference public subclass AlchemyNotNotesDocumentReference


::class AlchemyNotNotesFromReference public

/* Define a field source that enumerates references to one internal document type. */
::method init
  expose typeFilter
  use arg newTypeFilter
  if newTypeFilter == .nil then raise syntax 93.900 array ("FromReference requires a document type")
  typeFilter = newTypeFilter

::attribute typeFilter get

/* Return detached references to matching documents currently present on a node. */
::method references
  expose typeFilter
  use arg node
  refs = .array~new
  if node == .nil then return refs
  documents = node~documents(typeFilter)
  do document over documents
    refs~append(.DocumentReference~new(document~documentId, document~formName))
  end
  return refs

/* Test one resolved document against the configured internal type. */
::method acceptsDocument
  expose typeFilter
  use arg document
  return typeFilter~matches(document)

/* Reconstruct this source independently on the receiving replica. */
::method snapshotCopy
  expose typeFilter
  return .FromReference~new(.Document~type(typeFilter~formName))


::class FromReference public subclass AlchemyNotNotesFromReference


::class AlchemyNotNotesExternalDocument public

/* Capture one immutable-by-convention pasted/imported external payload. */
::method init
  expose externalId displayName mediaType content sourceKind
  use strict arg newExternalId, newDisplayName, newMediaType, newContent, newSourceKind = "EXTERNAL"
  if newExternalId == .nil then raise syntax 93.900 array ("externalId must not be empty")
  if newExternalId~string~strip = "" then raise syntax 93.900 array ("externalId must not be empty")
  if newMediaType == .nil then raise syntax 93.900 array ("mediaType must not be empty")
  if newMediaType~string~strip = "" then raise syntax 93.900 array ("mediaType must not be empty")
  externalId = newExternalId~string
  displayName = newDisplayName~string
  mediaType = newMediaType~string
  content = newContent
  sourceKind = newSourceKind~string

::attribute externalId get
::attribute displayName get
::attribute mediaType get
::attribute content get
::attribute sourceKind get

/* Report payload size in bytes for String-like pasted content. */
::method size
  expose content
  if content == .nil then return 0
  return content~string~length

/* Produce a detached external-payload snapshot for dependency replication. */
::method snapshot
  expose externalId displayName mediaType content sourceKind
  copiedContent = content
  if content \== .nil then copiedContent = content~string~substr(1)
  return .AlchemyNotNotesExternalDocumentSnapshot~new(externalId, displayName, mediaType, copiedContent, sourceKind)


::class AlchemyNotNotesExternalDocumentSnapshot public

/* Capture one detached external payload for replication. */
::method init
  expose externalId displayName mediaType content sourceKind
  use arg newExternalId, newDisplayName, newMediaType, newContent, newSourceKind
  externalId = newExternalId
  displayName = newDisplayName
  mediaType = newMediaType
  content = newContent
  sourceKind = newSourceKind

::attribute externalId get
::attribute displayName get
::attribute mediaType get
::attribute content get
::attribute sourceKind get

/* Materialise an independent external document from this snapshot. */
::method materialise
  expose externalId displayName mediaType content sourceKind
  copiedContent = content
  if content \== .nil then copiedContent = content~string~substr(1)
  return .AlchemyNotNotesExternalDocument~new(externalId, displayName, mediaType, copiedContent, sourceKind)


::class AlchemyNotNotesExternalDocumentLink public

/* Hold a durable field link to one external payload without embedding it in the document. */
::method init
  expose externalId displayName mediaType
  use arg newExternalId, newDisplayName, newMediaType
  externalId = newExternalId~string
  displayName = newDisplayName~string
  mediaType = newMediaType~string

::attribute externalId get
::attribute displayName get
::attribute mediaType get

/* Resolve this link against the external-content store of one local node. */
::method resolve
  expose externalId
  use arg node
  if node == .nil then return .nil
  return node~externalDocument(externalId)

/* Copy the durable link independently for a replicated document snapshot. */
::method snapshotCopy
  expose externalId displayName mediaType
  return .ExternalDocumentLink~new(externalId, displayName, mediaType)


::class ExternalDocumentLink public subclass AlchemyNotNotesExternalDocumentLink


::class AlchemyNotNotesFromExternalDocument public

/* Define a field source that accepts pasted/imported external media by MIME prefix. */
::method init
  expose mediaTypePrefix
  use strict arg newMediaTypePrefix = ""
  mediaTypePrefix = newMediaTypePrefix~string~lower

::attribute mediaTypePrefix get

/* Turn one node-local external payload into a durable field link. */
::method link
  expose mediaTypePrefix
  use arg externalDocument
  if externalDocument == .nil then raise syntax 93.900 array ("external document must not be .nil")
  if mediaTypePrefix <> "" then do
    candidate = externalDocument~mediaType~lower
    if left(candidate, length(mediaTypePrefix)) <> mediaTypePrefix then
      raise syntax 93.900 array ("external document media type is not accepted")
  end
  return .ExternalDocumentLink~new(externalDocument~externalId, externalDocument~displayName, externalDocument~mediaType)

/* Test a previously created link against this field's MIME policy. */
::method acceptsLink
  expose mediaTypePrefix
  use arg link
  if link == .nil then return .false
  if mediaTypePrefix = "" then return .true
  candidate = link~mediaType~lower
  return left(candidate, length(mediaTypePrefix)) = mediaTypePrefix

/* Reconstruct this source independently on the receiving replica. */
::method snapshotCopy
  expose mediaTypePrefix
  return .FromExternalDocument~new(mediaTypePrefix)


::class FromExternalDocument public subclass AlchemyNotNotesFromExternalDocument


::class AlchemyNotNotesField public

/* Define one document field and its semantic/intention exposure contract. */
::method init
  expose name source semanticType cardinality aliases intentionReadableValue intentionWritableValue intentionSearchableValue processOwnerValue computedValue
  use strict arg newName, newSource = .nil
  if newName == .nil then raise syntax 93.900 array ("field name must not be empty")
  if newName~string~strip = "" then raise syntax 93.900 array ("field name must not be empty")
  name = newName~string~upper
  source = newSource
  semanticType = "TEXT"
  cardinality = "ONE"
  aliases = .array~new
  intentionReadableValue = .true
  intentionWritableValue = .true
  intentionSearchableValue = .true
  processOwnerValue = ""
  computedValue = .false

::attribute name get
::attribute source get

/* Describe the value domain exposed to scripts and intention providers. */
::method semanticType
  expose semanticType
  use arg newValue = .nil
  if newValue \== .nil then do
    value = translate(strip(newValue~string))
    if value == "" then raise syntax 93.900 array ("semantic type must not be empty")
    semanticType = value
    return self
  end
  return semanticType

/* Describe whether the field contains one value or a collection. */
::method cardinality
  expose cardinality
  use arg newValue = .nil
  if newValue \== .nil then do
    value = translate(strip(newValue~string))
    if value \== "ONE" then do
      if value \== "MANY" then raise syntax 93.900 array ("field cardinality must be ONE or MANY")
    end
    cardinality = value
    return self
  end
  return cardinality

/* Add one natural-language alias without changing the Rexx field name. */
::method alias
  expose aliases
  use arg newAlias
  if newAlias == .nil then return self
  value = translate(strip(newAlias~string))
  if value == "" then return self
  do existing over aliases
    if existing == value then return self
  end
  aliases~append(value)
  return self

::method aliases
  expose aliases
  return aliases~copy

::method intentionReadable
  expose intentionReadableValue
  use arg newValue = .nil
  if newValue \== .nil then do
    intentionReadableValue = (newValue = .true)
    return self
  end
  return intentionReadableValue

::method intentionWritable
  expose intentionWritableValue
  use arg newValue = .nil
  if newValue \== .nil then do
    intentionWritableValue = (newValue = .true)
    return self
  end
  return intentionWritableValue

::method intentionSearchable
  expose intentionSearchableValue
  use arg newValue = .nil
  if newValue \== .nil then do
    intentionSearchableValue = (newValue = .true)
    return self
  end
  return intentionSearchableValue

/* Name the domain operation that owns mutation when generic SET_FIELD is inappropriate. */
::method processOwner
  expose processOwnerValue
  use arg newValue = .nil
  if newValue \== .nil then do
    processOwnerValue = translate(strip(newValue~string))
    return self
  end
  return processOwnerValue

/* Mark a derived field.  Computed fields are never directly intention-writable. */
::method computed
  expose computedValue intentionWritableValue
  use arg newValue = .nil
  if newValue \== .nil then do
    computedValue = (newValue = .true)
    if computedValue then intentionWritableValue = .false
    return self
  end
  return computedValue

/* Enumerate typed internal-document references when this is a FromReference field. */
::method references
  expose source
  use arg node
  if source == .nil then return .array~new
  if \source~isA(.AlchemyNotNotesFromReference) then return .array~new
  return source~references(node)

/* Build an external-document link when this field accepts external payloads. */
::method linkExternal
  expose source
  use arg externalDocument
  if source == .nil then raise syntax 93.900 array ("field has no source")
  if \source~isA(.AlchemyNotNotesFromExternalDocument) then
    raise syntax 93.900 array ("field is not an external-document field")
  return source~link(externalDocument)

/* Copy the field/source definition independently for a replicated document. */
::method snapshotCopy
  expose name source semanticType cardinality aliases intentionReadableValue intentionWritableValue intentionSearchableValue processOwnerValue computedValue
  sourceCopy = .nil
  if source \== .nil then sourceCopy = source~snapshotCopy
  copy = .Field~new(name, sourceCopy)
  copy~semanticType(semanticType)
  copy~cardinality(cardinality)
  do item over aliases
    copy~alias(item)
  end
  copy~intentionReadable(intentionReadableValue)
  copy~intentionWritable(intentionWritableValue)
  copy~intentionSearchable(intentionSearchableValue)
  copy~processOwner(processOwnerValue)
  copy~computed(computedValue)
  return copy


::class Field public subclass AlchemyNotNotesField


::class Document public subclass AlchemyNotNotesDocument

/* Provide the concise .Document~type("...") query vocabulary. */
::method type class
  use arg formName
  return .AlchemyNotNotesDocumentType~new(formName)



::class AlchemyNotNotesApprovalItem public

::method init
  expose name outcome signed evidence
  use strict arg newName, newOutcome, newSigned = .false, newEvidence = .nil
  if newName == .nil then raise syntax 93.900 array ("approval name must not be empty")
  if newName~string~strip = "" then raise syntax 93.900 array ("approval name must not be empty")
  name = newName~string
  outcome = (newOutcome = .true)
  signed = (newSigned = .true)
  evidence = newEvidence

::attribute name get
::attribute outcome get
::attribute signed get
::attribute evidence get

::method passed
  expose outcome
  return outcome

::method failed
  expose outcome
  return \outcome

::method snapshotCopy
  expose name outcome signed evidence
  return .ApprovalItem~new(name, outcome, signed, evidence)

::class ApprovalItem public subclass AlchemyNotNotesApprovalItem


::class AlchemyNotNotesApprovalSet public

::method init
  expose entries
  entries = .directory~new

::method evaluate
  expose entries
  use strict arg name, outcome, signed = .false, evidence = .nil
  item = .ApprovalItem~new(name, outcome, signed, evidence)
  entries~put(item, name~string~upper)
  return item

::method item
  expose entries
  use arg name
  if name == .nil then return .nil
  return entries~at(name~string~upper)

::method "[]"
  use arg name
  return self~item(name)

::method items
  expose entries
  return entries~items

::method anyFailed
  expose entries
  keys = entries~allIndexes
  do key over keys
    if entries~at(key)~failed then return .true
  end
  return .false

::method allPassed
  if self~items = 0 then return .false
  return \self~anyFailed

::method snapshotCopy
  expose entries
  copy = .ApprovalSet~new
  keys = entries~allIndexes
  do key over keys
    item = entries~at(key)
    copy~evaluate(item~name, item~outcome, item~signed, item~evidence)
  end
  return copy

/* Return detached approval items for transport-neutral state codecs. */
::method snapshotItems
  expose entries
  items = .array~new
  keys = entries~allIndexes
  do key over keys
    items~append(entries~at(key)~snapshotCopy)
  end
  return items

::class ApprovalSet public subclass AlchemyNotNotesApprovalSet


::class AlchemyNotNotesUserIdentity public

::method init
  expose identity displayName teamleader
  use strict arg newIdentity, newDisplayName = "", newTeamleader = .nil
  if newIdentity == .nil then raise syntax 93.900 array ("user identity must not be empty")
  if newIdentity~string~strip = "" then raise syntax 93.900 array ("user identity must not be empty")
  identity = newIdentity~string
  displayName = identity
  if newDisplayName \== .nil then do
    if newDisplayName~string~strip <> "" then displayName = newDisplayName~string
  end
  teamleader = newTeamleader

::attribute identity get
::attribute displayName get
::attribute teamleader get

::class UserIdentity public subclass AlchemyNotNotesUserIdentity


::class AlchemyNotNotesReferralDecision public

::method init
  expose actorIdentity outcome note
  use strict arg newActorIdentity, newOutcome, newNote = ""
  if newActorIdentity == .nil then raise syntax 93.900 array ("referral decision actor identity must not be empty")
  if newActorIdentity~string~strip = "" then raise syntax 93.900 array ("referral decision actor identity must not be empty")
  actorIdentity = newActorIdentity~string
  outcome = newOutcome~string~upper
  if outcome <> "APPROVED" then do
    if outcome <> "REJECTED" then raise syntax 93.900 array ("referral decision outcome must be APPROVED or REJECTED")
  end
  note = ""
  if newNote \== .nil then note = newNote~string

::attribute actorIdentity get
::attribute outcome get
::attribute note get

::method approved
  expose outcome
  return outcome = "APPROVED"

::method rejected
  expose outcome
  return outcome = "REJECTED"

::method snapshotCopy
  expose actorIdentity outcome note
  return .ReferralDecision~new(actorIdentity, outcome, note)

::class ReferralDecision public subclass AlchemyNotNotesReferralDecision


::class AlchemyNotNotesReferralItem public

::method init
  expose targetIdentity reason status decision
  use strict arg newTargetIdentity, newReason = "", newStatus = "OPEN", newDecision = .nil
  if newTargetIdentity == .nil then raise syntax 93.900 array ("referral target identity must not be empty")
  if newTargetIdentity~string~strip = "" then raise syntax 93.900 array ("referral target identity must not be empty")
  targetIdentity = newTargetIdentity~string
  reason = ""
  if newReason \== .nil then reason = newReason~string
  status = newStatus~string~upper
  if status <> "OPEN" then do
    if status <> "RESOLVED" then raise syntax 93.900 array ("referral status must be OPEN or RESOLVED")
  end
  decision = newDecision
  if status = "OPEN" then do
    if decision \== .nil then raise syntax 93.900 array ("open referral cannot carry a decision")
  end

::attribute targetIdentity get
::attribute reason get
::attribute status get
::attribute decision get

::method open
  expose status
  return status = "OPEN"

/* Legacy resolution without a decision remains representable but cannot approve a document. */
::method resolve
  expose status
  status = "RESOLVED"
  return self

/* Record immutable decision evidence and close this referral. */
::method decide
  expose status decision
  use strict arg actor, outcome, note = ""
  if status <> "OPEN" then raise syntax 93.900 array ("referral is already resolved")
  if actor == .nil then raise syntax 93.900 array ("referral decision actor must not be .nil")
  actorIdentity = actor~string
  if actor~isA(.AlchemyNotNotesUserIdentity) then actorIdentity = actor~identity
  decision = .ReferralDecision~new(actorIdentity, outcome, note)
  status = "RESOLVED"
  return decision

::method approve
  use strict arg actor, note = ""
  return self~decide(actor, "APPROVED", note)

::method reject
  use strict arg actor, note = ""
  return self~decide(actor, "REJECTED", note)

::method snapshotCopy
  expose targetIdentity reason status decision
  decisionCopy = .nil
  if decision \== .nil then decisionCopy = decision~snapshotCopy
  return .ReferralItem~new(targetIdentity, reason, status, decisionCopy)

::class ReferralItem public subclass AlchemyNotNotesReferralItem


::class AlchemyNotNotesReferralSet public

::method init
  expose entries
  entries = .directory~new

::method refer
  expose entries
  use strict arg targetIdentity, reason = ""
  key = targetIdentity~string~upper
  reasonText = ""
  if reason \== .nil then reasonText = reason~string
  existing = entries~at(key)
  if existing \== .nil then do
    if existing~open then do
      if existing~reason = reasonText then return existing
    end
  end
  item = .ReferralItem~new(targetIdentity, reasonText)
  entries~put(item, key)
  return item

::method item
  expose entries
  use arg targetIdentity
  if targetIdentity == .nil then return .nil
  return entries~at(targetIdentity~string~upper)

::method "[]"
  use arg targetIdentity
  return self~item(targetIdentity)

::method items
  expose entries
  return entries~items

::method hasOpenFor
  use arg targetIdentity
  item = self~item(targetIdentity)
  if item == .nil then return .false
  return item~open

::method anyOpen
  expose entries
  keys = entries~allIndexes
  do key over keys
    if entries~at(key)~open then return .true
  end
  return .false

::method anyRejected
  expose entries
  keys = entries~allIndexes
  do key over keys
    item = entries~at(key)
    if item~open then iterate
    decision = item~decision
    if decision == .nil then iterate
    if decision~rejected then return .true
  end
  return .false

::method allResolvedApproved
  expose entries
  if entries~items = 0 then return .false
  keys = entries~allIndexes
  do key over keys
    item = entries~at(key)
    if item~open then return .false
    decision = item~decision
    if decision == .nil then return .false
    if \decision~approved then return .false
  end
  return .true

::method snapshotCopy
  expose entries
  copy = .ReferralSet~new
  keys = entries~allIndexes
  do key over keys
    item = entries~at(key)
    copyItem = copy~refer(item~targetIdentity, item~reason)
    if \item~open then do
      decision = item~decision
      if decision == .nil then copyItem~resolve
      else copyItem~decide(decision~actorIdentity, decision~outcome, decision~note)
    end
  end
  return copy

/* Return detached referral items for transport-neutral state codecs. */
::method snapshotItems
  expose entries
  items = .array~new
  keys = entries~allIndexes
  do key over keys
    items~append(entries~at(key)~snapshotCopy)
  end
  return items

::class ReferralSet public subclass AlchemyNotNotesReferralSet


::class AlchemyNotNotesDispatchContext public

::method init
  expose node document eventName
  use strict arg newNode, newDocument, newEventName
  node = newNode
  document = newDocument
  eventName = newEventName~string~upper

::attribute node get
::attribute document get
::attribute eventName get

/* Return the node-local principal supplied to this dispatch, never document-carried authority. */
::method user
  expose node
  return node~currentUser

::class DispatchContext public subclass AlchemyNotNotesDispatchContext


::class AlchemyNotNotesDispatchResult public

::method init
  expose status detail value
  use strict arg newStatus, newDetail = "", newValue = .nil
  status = newStatus~string
  detail = newDetail~string
  value = newValue

::attribute status get
::attribute detail get
::attribute value get

::method executed
  expose status
  return status = "EXECUTED"

::class DispatchResult public subclass AlchemyNotNotesDispatchResult


::class AlchemyNotNotesControllerSandbox public

::method init
  expose securityManager
  use arg newSecurityManager
  securityManager = newSecurityManager

::method dispatch
  expose securityManager
  use strict arg node, document, eventName
  handler = document~scriptHandler(eventName)
  if handler == .nil then return .DispatchResult~new("NO_HANDLER", eventName)

  sourceLines = .array~new
  sourceLines~append("This = self~at('DISPATCHCONTEXT')")
  sourceLines~append(handler~source)
  method = .Method~new("", sourceLines)
  if securityManager \== .nil then method~setSecurityManager(securityManager)

  controller = .Directory~new
  controller~put(.DispatchContext~new(node, document, eventName), "DISPATCHCONTEXT")
  controller~setMethod("HANDLER", method)
  auditBefore = 0
  if securityManager \== .nil then auditBefore = securityManager~auditLog~items

  signal on syntax name dispatchFailure
  dispatchValue = controller~at("HANDLER")
  signal off syntax
  return .DispatchResult~new("EXECUTED", "", dispatchValue)

dispatchFailure:
  say "ControllerSandbox dispatchFailure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  dispatchRC = rc
  dispatchLine = sigl
  dispatchCondition = condition("C")
  dispatchDescription = condition("D")
  dispatchStatus = "FAILED"
  if securityManager \== .nil then do
    if securityManager~auditLog~items > auditBefore then dispatchStatus = "BLOCKED"
  end
  if dispatchRC = 93.901 then dispatchStatus = "BLOCKED"
  else if pos("RTOSecurityManager", dispatchDescription) > 0 then dispatchStatus = "BLOCKED"
  return .DispatchResult~new(dispatchStatus, dispatchDescription)

::class ControllerSandbox public subclass AlchemyNotNotesControllerSandbox


::class AlchemyNotNotesScriptHandler public

/* Capture one named script-section handler as source bound to a definition version. */
::method init
  expose eventName source
  use strict arg newEventName, newSource
  if newEventName == .nil then raise syntax 93.900 array ("script event name must not be empty")
  if newEventName~string~strip = "" then raise syntax 93.900 array ("script event name must not be empty")
  if newSource == .nil then raise syntax 93.900 array ("script source must not be .nil")
  eventName = newEventName~string~upper
  source = newSource~string

::attribute eventName get
::attribute source get

/* Copy source independently so design/document replicas never share handler objects. */
::method snapshotCopy
  expose eventName source
  return .ScriptHandler~new(eventName, source)


::class ScriptHandler public subclass AlchemyNotNotesScriptHandler


::class AlchemyNotNotesDocumentDefinition public

/* Initialise one immutable-by-registration versioned document definition. */
::method init
  expose name version identity formName fields handlers sealed
  use strict arg newName, newVersion, newFormName = ""
  if newName == .nil then raise syntax 93.900 array ("document definition name must not be empty")
  if newName~string~strip = "" then raise syntax 93.900 array ("document definition name must not be empty")
  if newVersion == .nil then raise syntax 93.900 array ("document definition version must not be empty")
  if newVersion~string~strip = "" then raise syntax 93.900 array ("document definition version must not be empty")
  name = newName~string
  version = newVersion~string
  identity = name || "/" || version
  if newFormName == .nil | newFormName~string~strip = "" then formName = name
  else formName = newFormName~string
  fields = .directory~new
  handlers = .directory~new
  sealed = .false

::attribute name get
::attribute version get
::attribute identity get
::attribute formName get
::attribute sealed get

/* Return detached field names for semantic/application introspection. */
::method fieldNames
  expose fields
  names = .array~new
  indexes = fields~allIndexes
  do name over indexes
    names~append(name)
  end
  return names

/* Return one immutable field-definition copy by name. */
::method fieldDefinition
  expose fields
  use arg fieldName
  if fieldName == .nil then return .nil
  key = fieldName~string~upper
  if fields~hasIndex(key) = 0 then return .nil
  return fields~at(key)~snapshotCopy

/* Add one first-class field before the definition is sealed. */
::method field
  expose fields sealed
  use strict arg fieldName, source = .nil
  if sealed then raise syntax 93.900 array ("document definition is sealed")
  field = .Field~new(fieldName, source)
  fields~put(field, field~name)
  return field

/* Add one named script-section handler before this definition is sealed. */
::method handler
  expose handlers sealed
  use strict arg eventName, source
  if sealed then raise syntax 93.900 array ("document definition is sealed")
  scriptHandler = .ScriptHandler~new(eventName, source)
  handlers~put(scriptHandler, scriptHandler~eventName)
  return scriptHandler

/* Return one exact handler definition by event name. */
::method handlerFor
  expose handlers
  use arg eventName
  if eventName == .nil then return .nil
  return handlers~at(eventName~string~upper)

/* Seal this exact version against accidental in-place business-rule changes. */
::method seal
  expose sealed
  sealed = .true
  return self

/* Compose a real ooRexx Document instance from this exact definition. */
::method compose
  expose identity formName fields handlers
  use arg node
  if node == .nil then raise syntax 93.900 array ("compose requires a node")
  document = node~createDocument(formName)
  document~bindDefinition(identity)
  names = fields~allIndexes
  do name over names
    definition = fields~at(name)~snapshotCopy
    document~defineField(definition~name, definition~source)
  end
  eventNames = handlers~allIndexes
  do eventName over eventNames
    document~installScriptHandler(handlers~at(eventName))
  end
  return document

/* Make an independent immutable design copy for installation on another node. */
::method snapshotCopy
  expose name version formName fields handlers sealed
  copy = .DocumentDefinition~new(name, version, formName)
  names = fields~allIndexes
  do fieldName over names
    field = fields~at(fieldName)~snapshotCopy
    targetField = copy~field(field~name, field~source)
    targetField~semanticType(field~semanticType)
    targetField~cardinality(field~cardinality)
    do fieldAlias over field~aliases
      targetField~alias(fieldAlias)
    end
    targetField~intentionReadable(field~intentionReadable)
    targetField~intentionWritable(field~intentionWritable)
    targetField~intentionSearchable(field~intentionSearchable)
    targetField~processOwner(field~processOwner)
    targetField~computed(field~computed)
  end
  eventNames = handlers~allIndexes
  do eventName over eventNames
    handler = handlers~at(eventName)
    copy~handler(handler~eventName, handler~source)
  end
  if sealed then copy~seal
  return copy


::class DocumentDefinition public subclass AlchemyNotNotesDocumentDefinition


::class AlchemyNotNotesViewColumn public

/* Define one named projection column as an object-message path. */
::method init
  expose name path
  use arg newName, newPath
  if newName == .nil then raise syntax 93.900 array ("view column name must not be empty")
  if newName~string~strip = "" then raise syntax 93.900 array ("view column name must not be empty")
  if newPath == .nil then newPath = newName
  if newPath~string~strip = "" then newPath = newName
  name = newName~string
  path = newPath~string

::attribute name get
::attribute path get

/* Copy this immutable view-column definition. */
::method snapshotCopy
  expose name path
  return .AlchemyNotNotesViewColumn~new(name, path)


::class AlchemyNotNotesViewRow public

/* Capture an ephemeral presentation projection, never authoritative state. */
::method init
  expose documentId values
  use arg newDocumentId, newValues
  documentId = newDocumentId
  values = newValues

::attribute documentId get

/* Return one projected display value by column name. */
::method value
  expose values
  use arg columnName
  if columnName == .nil then return .nil
  return values~at(columnName~string~upper)

/* Resolve the underlying authoritative document on one local node. */
::method document
  expose documentId
  use arg node
  if node == .nil then return .nil
  return node~document(documentId)


::class AlchemyNotNotesViewDefinition public

/* Initialise one exact versioned local projection over document objects. */
::method init
  expose name version identity typeFilter columns sortPath descending sealed
  use strict arg newName, newVersion, newTypeFilter = .nil
  if newName == .nil then raise syntax 93.900 array ("view name must not be empty")
  if newName~string~strip = "" then raise syntax 93.900 array ("view name must not be empty")
  if newVersion == .nil then raise syntax 93.900 array ("view version must not be empty")
  if newVersion~string~strip = "" then raise syntax 93.900 array ("view version must not be empty")
  name = newName~string
  version = newVersion~string
  identity = name || "/" || version
  typeFilter = newTypeFilter
  columns = .array~new
  sortPath = ""
  descending = .false
  sealed = .false

::attribute name get
::attribute version get
::attribute identity get
::attribute sealed get

/* Return detached view-column definitions for semantic/application introspection. */
::method columnDefinitions
  expose columns
  out = .array~new
  do column over columns
    out~append(column~snapshotCopy)
  end
  return out

/* Add one display projection path before sealing the view definition. */
::method column
  expose columns sealed
  use strict arg columnName, path = ""
  if sealed then raise syntax 93.900 array ("view definition is sealed")
  if path == .nil | path~string~strip = "" then path = columnName
  columns~append(.AlchemyNotNotesViewColumn~new(columnName, path))
  return self

/* Set the local ordering projection for this view. */
::method sortBy
  expose sortPath descending sealed
  use strict arg path, direction = "ASC"
  if sealed then raise syntax 93.900 array ("view definition is sealed")
  if path == .nil then raise syntax 93.900 array ("view sort path must not be empty")
  if path~string~strip = "" then raise syntax 93.900 array ("view sort path must not be empty")
  sortPath = path~string
  descending = direction~string~upper = "DESC"
  return self

/* Seal this exact view definition against in-place mutation. */
::method seal
  expose sealed
  sealed = .true
  return self

/* Return authoritative local documents selected and ordered by this view. */
::method documents
  expose typeFilter
  use arg node
  if node == .nil then return .array~new
  documents = node~documents(typeFilter)
  return self~sortDocuments(documents)

/* Return ephemeral presentation rows calculated from current local documents. */
::method rows
  expose columns
  use arg node
  rows = .array~new
  documents = self~documents(node)
  do document over documents
    values = .directory~new
    do column over columns
      values~put(self~resolvePath(document, column~path), column~name~upper)
    end
    rows~append(.AlchemyNotNotesViewRow~new(document~documentId, values))
  end
  return rows

/* Make an independent view-definition copy for another node. */
::method snapshotCopy
  expose name version typeFilter columns sortPath descending sealed
  typeCopy = .nil
  if typeFilter \== .nil then typeCopy = .Document~type(typeFilter~formName)
  copy = .ViewDefinition~new(name, version, typeCopy)
  do column over columns
    copy~column(column~name, column~path)
  end
  if sortPath <> "" then do
    direction = "ASC"
    if descending then direction = "DESC"
    copy~sortBy(sortPath, direction)
  end
  if sealed then copy~seal
  return copy

/* Resolve dotted object-message paths such as Customer.CompanyName locally. */
::method resolvePath
  use arg root, path
  if root == .nil then return .nil
  if path == .nil then return .nil
  words = translate(path~string, " ", ".")
  current = root
  do i = 1 to words(words)
    if current == .nil then return .nil
    current = current~send(word(words, i))
  end
  return current

/* Sort a detached Array of document references without changing store state. */
::method sortDocuments
  expose sortPath
  use arg documents
  if sortPath = "" then return documents
  if documents~items < 2 then return documents
  documents~sortWith(.AlchemyNotNotesViewComparator~new(self))
  return documents

/* Return Comparator ordering for two documents using this view's sort path. */
::method compareDocuments
  expose sortPath descending
  use arg leftDocument, rightDocument
  leftValue = self~resolvePath(leftDocument, sortPath)
  rightValue = self~resolvePath(rightDocument, sortPath)
  if leftValue == .nil then leftText = ""
  else leftText = leftValue~string
  if rightValue == .nil then rightText = ""
  else rightText = rightValue~string
  comparison = leftText~caselessCompareTo(rightText)
  if descending then return 0 - comparison
  return comparison


::class AlchemyNotNotesViewComparator public subclass Comparator

/* Bind Array sorting to one versioned view definition. */
::method init
  expose viewDefinition
  use arg newViewDefinition
  viewDefinition = newViewDefinition

/* Delegate one comparison to the view's configured projection semantics. */
::method compare
  expose viewDefinition
  use arg leftDocument, rightDocument
  return viewDefinition~compareDocuments(leftDocument, rightDocument)


::class ViewDefinition public subclass AlchemyNotNotesViewDefinition


::class AlchemyNotNotesApplicationDefinition public

/* Collect independently versioned document and view definitions for installation. */
::method init
  expose name version identity documentDefinitions viewDefinitions sealed
  use arg newName, newVersion
  if newName == .nil then raise syntax 93.900 array ("application name must not be empty")
  if newName~string~strip = "" then raise syntax 93.900 array ("application name must not be empty")
  if newVersion == .nil then raise syntax 93.900 array ("application version must not be empty")
  if newVersion~string~strip = "" then raise syntax 93.900 array ("application version must not be empty")
  name = newName~string
  version = newVersion~string
  identity = name || "/" || version
  documentDefinitions = .directory~new
  viewDefinitions = .directory~new
  sealed = .false

::attribute name get
::attribute version get
::attribute identity get
::attribute sealed get

/* Return detached exact document-definition identities in this application version. */
::method documentDefinitionIds
  expose documentDefinitions
  ids = .array~new
  indexes = documentDefinitions~allIndexes
  do identity over indexes
    ids~append(identity)
  end
  return ids

/* Return one independent document-definition copy by exact identity. */
::method documentDefinition
  expose documentDefinitions
  use arg identity
  if identity == .nil then return .nil
  key = identity~string
  if documentDefinitions~hasIndex(key) = 0 then return .nil
  return documentDefinitions~at(key)~snapshotCopy

/* Return detached exact view-definition identities in this application version. */
::method viewDefinitionIds
  expose viewDefinitions
  ids = .array~new
  indexes = viewDefinitions~allIndexes
  do identity over indexes
    ids~append(identity)
  end
  return ids

/* Return one independent view-definition copy by exact identity. */
::method viewDefinition
  expose viewDefinitions
  use arg identity
  if identity == .nil then return .nil
  key = identity~string
  if viewDefinitions~hasIndex(key) = 0 then return .nil
  return viewDefinitions~at(key)~snapshotCopy

/* Add one exact document definition to this application version. */
::method addDocumentDefinition
  expose documentDefinitions sealed
  use arg definition
  if sealed then raise syntax 93.900 array ("application definition is sealed")
  if definition == .nil then raise syntax 93.900 array ("document definition must not be .nil")
  documentDefinitions~put(definition, definition~identity)
  return definition

/* Add one exact view definition to this application version. */
::method addViewDefinition
  expose viewDefinitions sealed
  use arg definition
  if sealed then raise syntax 93.900 array ("application definition is sealed")
  if definition == .nil then raise syntax 93.900 array ("view definition must not be .nil")
  viewDefinitions~put(definition, definition~identity)
  return definition

/* Seal this application and all contained exact definition versions. */
::method seal
  expose documentDefinitions viewDefinitions sealed
  docs = documentDefinitions~allIndexes
  do identity over docs
    documentDefinitions~at(identity)~seal
  end
  views = viewDefinitions~allIndexes
  do identity over views
    viewDefinitions~at(identity)~seal
  end
  sealed = .true
  return self

/* Install independent design objects on one autonomous local node. */
::method install
  expose documentDefinitions viewDefinitions
  use arg node
  if node == .nil then raise syntax 93.900 array ("install requires a node")
  docs = documentDefinitions~allIndexes
  do identity over docs
    node~registerDocumentDefinition(documentDefinitions~at(identity)~snapshotCopy)
  end
  views = viewDefinitions~allIndexes
  do identity over views
    node~registerViewDefinition(viewDefinitions~at(identity)~snapshotCopy)
  end
  return node


::class ApplicationDefinition public subclass AlchemyNotNotesApplicationDefinition


::class AlchemyNotNotesMemoryStore public

/* Initialise a minimal node-local object store adapter. */
::method init
  expose documents
  documents = .directory~new

/* Store a document by durable identity. */
::method put
  expose documents
  use arg document
  documents~put(document, document~documentId)
  return document

/* Fetch a document by durable identity. */
::method get
  expose documents
  use arg documentId
  return documents~at(documentId)

/* Test whether a document exists. */
::method has
  expose documents
  use arg documentId
  return documents~hasIndex(documentId)

/* Return detached document identities known to this store. */
::method allDocumentIds
  expose documents
  ids = .array~new
  indexes = documents~allIndexes
  do index over indexes
    ids~append(index)
  end
  return ids

/* Select authoritative object instances, optionally by one document type. */
::method select
  expose documents
  use strict arg typeFilter = .nil
  selected = .array~new
  indexes = documents~allIndexes
  do documentId over indexes
    document = documents~at(documentId)
    if document == .nil then iterate
    if typeFilter == .nil then do
      selected~append(document)
      iterate
    end
    if typeFilter~matches(document) then selected~append(document)
  end
  return selected

/* Resolve inbound relationship edges inside this store implementation. */
::method linkedTo
  expose documents
  use strict arg targetDocumentId, typeFilter = .nil
  selected = .array~new
  indexes = documents~allIndexes
  do candidateId over indexes
    if candidateId = targetDocumentId then iterate
    candidate = documents~at(candidateId)
    if candidate == .nil then iterate
    if \candidate~linksTo(targetDocumentId) then iterate
    if typeFilter == .nil then do
      selected~append(candidate)
      iterate
    end
    if typeFilter~matches(candidate) then selected~append(candidate)
  end
  return selected


::class AlchemyNotNotesNode public

/* Initialise one autonomous local notNotes node. */
::method init
  expose nodeId store nextDocumentNumber externalDocuments nextExternalNumber documentDefinitions viewDefinitions securityManager currentUserObject
  use strict arg newNodeId, newStore = (.AlchemyNotNotesMemoryStore~new)
  if newNodeId == .nil then raise syntax 93.900 array ("nodeId must not be empty")
  if newNodeId~string~strip = "" then raise syntax 93.900 array ("nodeId must not be empty")
  nodeId = newNodeId~string
  if newStore == .nil then newStore = .AlchemyNotNotesMemoryStore~new
  store = newStore
  nextDocumentNumber = 0
  externalDocuments = .directory~new
  nextExternalNumber = 0
  documentDefinitions = .directory~new
  viewDefinitions = .directory~new
  securityManager = .nil
  currentUserObject = .nil

::attribute nodeId get

/* Supply the node-local principal used by travelling business code. */
::method setCurrentUser
  expose currentUserObject
  use arg user
  currentUserObject = user
  return self

/* Return the current node-local principal for this execution context. */
::method currentUser
  expose currentUserObject
  return currentUserObject

/* Supply the node-local authority used for travelling document code. */
::method setSecurityManager
  expose securityManager
  use arg manager
  securityManager = manager
  return self

::method securityManager
  expose securityManager
  return securityManager

/* Execute one carried document handler under this node's security policy. */
::method dispatch
  expose securityManager
  use strict arg document, eventName
  if document == .nil then raise syntax 93.900 array ("dispatch document must not be .nil")
  sandbox = .ControllerSandbox~new(securityManager)
  return sandbox~dispatch(self, document, eventName)

/* Register one exact sealed document-definition version on this node. */
::method registerDocumentDefinition
  expose documentDefinitions
  use arg definition
  if definition == .nil then raise syntax 93.900 array ("document definition must not be .nil")
  definition~seal
  documentDefinitions~put(definition, definition~identity)
  return definition

/* Return one exact document definition by identity, never by implicit latest. */
::method documentDefinition
  expose documentDefinitions
  use arg identity
  if identity == .nil then return .nil
  return documentDefinitions~at(identity~string)

/* Return detached exact document-definition identities installed locally. */
::method documentDefinitionIds
  expose documentDefinitions
  ids = .array~new
  indexes = documentDefinitions~allIndexes
  do identity over indexes
    ids~append(identity)
  end
  return ids

/* Compose one unsaved document using an exact registered definition identity. */
::method compose
  use arg definitionIdentity
  definition = self~documentDefinition(definitionIdentity)
  if definition == .nil then raise syntax 93.900 array ("document definition is not registered: " || definitionIdentity)
  return definition~compose(self)

/* Register one exact sealed view-definition version on this node. */
::method registerViewDefinition
  expose viewDefinitions
  use arg definition
  if definition == .nil then raise syntax 93.900 array ("view definition must not be .nil")
  definition~seal
  viewDefinitions~put(definition, definition~identity)
  return definition

/* Return one exact local view definition by identity. */
::method viewDefinition
  expose viewDefinitions
  use arg identity
  if identity == .nil then return .nil
  return viewDefinitions~at(identity~string)

/* Return detached exact view-definition identities installed locally. */
::method viewDefinitionIds
  expose viewDefinitions
  ids = .array~new
  indexes = viewDefinitions~allIndexes
  do identity over indexes
    ids~append(identity)
  end
  return ids

/* Evaluate one exact registered view against this node's local object population. */
::method view
  use arg identity
  definition = self~viewDefinition(identity)
  if definition == .nil then raise syntax 93.900 array ("view definition is not registered: " || identity)
  return definition~rows(self)

/* Create a new unsaved document owned initially by this node. */
::method createDocument
  expose nodeId nextDocumentNumber
  use arg formName
  nextDocumentNumber += 1
  documentId = nodeId || "/DOC/" || nextDocumentNumber
  document = .Document~new(documentId, formName)
  document~attachNode(self)
  return document

/* Commit and store a local document revision. */
::method save
  expose nodeId store
  use arg document
  if document == .nil then raise syntax 93.900 array ("document must not be .nil")
  document~attachNode(self)
  document~commit(nodeId)
  store~put(document)
  return document

/* Return a locally stored document, or .nil when absent. */
::method document
  expose store
  use arg documentId
  return store~get(documentId)

/* Return all locally stored document identities. */
::method documentIds
  expose store
  return store~allDocumentIds

/* Return local documents through the object-store selection seam. */
::method documents
  expose store
  use strict arg typeFilter = .nil
  return store~select(typeFilter)

/* Return the local approval/referral tray for one identity. */
::method referralTray
  expose store
  use arg target
  selected = .array~new
  if target == .nil then return selected
  targetIdentity = target~string
  if target~isA(.AlchemyNotNotesUserIdentity) then targetIdentity = target~identity
  documents = store~select
  do document over documents
    if document~Referrals~hasOpenFor(targetIdentity) then selected~append(document)
  end
  return selected

/* Decide the current node-local user's referral and commit a new document revision. */
::method decideReferral
  expose currentUserObject
  use strict arg document, outcome, note = ""
  if currentUserObject == .nil then raise syntax 93.900 array ("referral decision requires a current node user")
  if document == .nil then raise syntax 93.900 array ("referral decision requires a document")
  item = document~Referrals~item(currentUserObject~identity)
  if item == .nil then raise syntax 93.900 array ("document has no referral for current user")
  decision = item~decide(currentUserObject, outcome, note)
  self~save(document)
  return decision

/* Create one immutable external payload in this node's local content store. */
::method createExternalDocument
  expose nodeId externalDocuments nextExternalNumber
  use strict arg displayName, mediaType, content, sourceKind = "EXTERNAL"
  nextExternalNumber += 1
  externalId = nodeId || "/EXT/" || nextExternalNumber
  external = .AlchemyNotNotesExternalDocument~new(externalId, displayName, mediaType, content, sourceKind)
  externalDocuments~put(external, externalId)
  return external

/* Capture a pasted image/video/etc. as an immutable external payload. */
::method pasteExternalDocument
  use strict arg displayName, mediaType, content
  return self~createExternalDocument(displayName, mediaType, content, "PASTE")

/* Return one node-local external payload by durable identity. */
::method externalDocument
  expose externalDocuments
  use arg externalId
  if externalId == .nil then return .nil
  return externalDocuments~at(externalId~string)

/* Admit one immutable external payload snapshot without identity collision. */
::method receiveExternalSnapshot
  expose externalDocuments
  use arg snapshot
  if snapshot == .nil then
    return .AlchemyNotNotesReplicationResult~new("REJECTED", "external snapshot is .nil")
  existing = externalDocuments~at(snapshot~externalId)
  if existing == .nil then do
    externalDocuments~put(snapshot~materialise, snapshot~externalId)
    return .AlchemyNotNotesReplicationResult~new("CREATED", snapshot~externalId)
  end
  same = existing~displayName = snapshot~displayName
  same = same & existing~mediaType = snapshot~mediaType
  same = same & existing~sourceKind = snapshot~sourceKind
  same = same & existing~content = snapshot~content
  if same then return .AlchemyNotNotesReplicationResult~new("UNCHANGED", snapshot~externalId)
  return .AlchemyNotNotesReplicationResult~new("CONFLICT", "external document identity collision: " || snapshot~externalId)

/* Resolve inbound document links through the object-store relationship seam. */
::method linkedDocumentsTo
  expose store
  use strict arg targetDocumentId, typeFilter = .nil
  return store~linkedTo(targetDocumentId, typeFilter)

/* Export only replayable business state.  Local authority/design registries stay local. */
::method rtoExportState
  expose nodeId store nextDocumentNumber externalDocuments nextExternalNumber
  state = .directory~new
  state["schema"] = "alchemy.notnotes.rto-state/1"
  state["nodeId"] = nodeId
  state["nextDocumentNumber"] = nextDocumentNumber
  state["nextExternalNumber"] = nextExternalNumber

  documents = .array~new
  ids = store~allDocumentIds
  do documentId over ids
    documents~append(.AlchemyNotNotesRTOCodec~encodeDocument(store~get(documentId)))
  end
  state["documents"] = documents

  externals = .array~new
  externalIds = externalDocuments~allIndexes
  do externalId over externalIds
    externals~append(.AlchemyNotNotesRTOCodec~encodeExternalDocument(externalDocuments~at(externalId)))
  end
  state["externals"] = externals
  return state

/* Replace replayable state atomically after fully decoding it. */
::method rtoImportState
  expose nodeId store nextDocumentNumber externalDocuments nextExternalNumber
  use arg state
  if state == .nil then raise syntax 93.900 array ("NotNotes RTO state must not be .nil")
  if state["schema"] <> "alchemy.notnotes.rto-state/1" then
    raise syntax 93.900 array ("unsupported NotNotes RTO state schema")
  if state["nodeId"] <> nodeId then
    raise syntax 93.900 array ("NotNotes RTO logical node identity mismatch")

  incomingStore = .AlchemyNotNotesMemoryStore~new
  documents = state["documents"]
  if documents == .nil then documents = .array~new
  do documentState over documents
    document = .AlchemyNotNotesRTOCodec~decodeDocument(documentState)
    document~attachNode(self)
    incomingStore~put(document)
  end

  incomingExternals = .directory~new
  externals = state["externals"]
  if externals == .nil then externals = .array~new
  do externalState over externals
    external = .AlchemyNotNotesRTOCodec~decodeExternalDocument(externalState)
    incomingExternals~put(external, external~externalId)
  end

  incomingDocumentNumber = state["nextDocumentNumber"]
  incomingExternalNumber = state["nextExternalNumber"]
  if incomingDocumentNumber == .nil then incomingDocumentNumber = 0
  if incomingExternalNumber == .nil then incomingExternalNumber = 0
  if \incomingDocumentNumber~datatype("W") then
    raise syntax 93.900 array ("invalid NotNotes RTO document counter")
  if \incomingExternalNumber~datatype("W") then
    raise syntax 93.900 array ("invalid NotNotes RTO external counter")

  store = incomingStore
  externalDocuments = incomingExternals
  nextDocumentNumber = incomingDocumentNumber
  nextExternalNumber = incomingExternalNumber
  return self

/* Establish an explicit point-to-point replication session. */
::method connect
  use arg peerNode
  if peerNode == .nil then raise syntax 93.900 array ("peer node must not be .nil")
  return .AlchemyNotNotesReplicator~new(self, peerNode)

/* Admit an incoming snapshot after deterministic ancestry checks. */
::method receiveSnapshot
  expose store
  use arg snapshot
  if snapshot == .nil then
    return .AlchemyNotNotesReplicationResult~new("REJECTED", "snapshot is .nil")

  existing = store~get(snapshot~documentId)
  if existing == .nil then do
    imported = .Document~fromSnapshot(snapshot)
    imported~attachNode(self)
    store~put(imported)
    return .AlchemyNotNotesReplicationResult~new("CREATED", snapshot~revisionId)
  end

  if existing~revisionId = snapshot~revisionId then
    return .AlchemyNotNotesReplicationResult~new("UNCHANGED", snapshot~revisionId)

  /* Incoming state is a descendant of our current state: safe fast-forward. */
  if snapshot~hasAncestor(existing~revisionId) then do
    existing~loadSnapshot(snapshot)
    existing~attachNode(self)
    store~put(existing)
    return .AlchemyNotNotesReplicationResult~new("UPDATED", snapshot~revisionId)
  end

  /* Our local state already descends from the incoming state: ignore stale input. */
  existingSnapshot = existing~snapshot
  if existingSnapshot~hasAncestor(snapshot~revisionId) then
    return .AlchemyNotNotesReplicationResult~new("STALE", snapshot~revisionId)

  /* Both replicas changed from a common ancestor: surface, never overwrite. */
  return .AlchemyNotNotesReplicationResult~new("CONFLICT", existing~revisionId || " <> " || snapshot~revisionId)


::class AlchemyNotNotesRTOCodec public

/* Encode one document revision as a JSON-compatible value graph. */
::method encodeDocument class
  use arg document
  if document == .nil then raise syntax 93.900 array ("cannot encode .nil document")
  snapshot = document~snapshot
  state = .directory~new
  state["documentId"] = snapshot~documentId
  state["formName"] = snapshot~formName
  state["definitionIdentity"] = snapshot~definitionIdentity
  state["revision"] = snapshot~revision
  state["revisionId"] = snapshot~revisionId
  state["lastWriterNode"] = snapshot~lastWriterNode

  lineage = .array~new
  do revisionId over snapshot~lineage
    lineage~append(revisionId)
  end
  state["lineage"] = lineage

  fields = .array~new
  fieldNames = snapshot~fields~allIndexes
  do fieldName over fieldNames
    fieldState = .directory~new
    fieldState["name"] = fieldName
    fieldState["value"] = self~encodeValue(snapshot~fields~at(fieldName))
    fields~append(fieldState)
  end
  state["fields"] = fields

  definitions = .array~new
  definitionNames = snapshot~fieldDefinitions~allIndexes
  do fieldName over definitionNames
    definitions~append(self~encodeField(snapshot~fieldDefinitions~at(fieldName)))
  end
  state["fieldDefinitions"] = definitions

  handlers = .array~new
  eventNames = snapshot~scriptHandlers~allIndexes
  do eventName over eventNames
    handler = snapshot~scriptHandlers~at(eventName)
    handlerState = .directory~new
    handlerState["eventName"] = handler~eventName
    handlerState["source"] = handler~source
    handlers~append(handlerState)
  end
  state["scriptHandlers"] = handlers

  links = .array~new
  linkIds = snapshot~links~allIndexes
  do linkId over linkIds
    link = snapshot~links~at(linkId)
    linkState = .directory~new
    linkState["documentId"] = link~documentId
    linkState["name"] = link~name
    links~append(linkState)
  end
  state["links"] = links
  return state

/* Reconstruct one detached document from JSON-compatible state. */
::method decodeDocument class
  use arg state
  fields = .directory~new
  fieldStates = state["fields"]
  if fieldStates == .nil then fieldStates = .array~new
  do fieldState over fieldStates
    fields~put(self~decodeValue(fieldState["value"]), fieldState["name"])
  end

  definitions = .directory~new
  definitionStates = state["fieldDefinitions"]
  if definitionStates == .nil then definitionStates = .array~new
  do definitionState over definitionStates
    field = self~decodeField(definitionState)
    definitions~put(field, field~name)
  end

  handlers = .directory~new
  handlerStates = state["scriptHandlers"]
  if handlerStates == .nil then handlerStates = .array~new
  do handlerState over handlerStates
    handler = .ScriptHandler~new(handlerState["eventName"], handlerState["source"])
    handlers~put(handler, handler~eventName)
  end

  links = .directory~new
  linkStates = state["links"]
  if linkStates == .nil then linkStates = .array~new
  do linkState over linkStates
    link = .AlchemyNotNotesDocumentLink~new(linkState["documentId"], linkState["name"])
    links~put(link, link~documentId)
  end

  lineage = .array~new
  lineageState = state["lineage"]
  if lineageState == .nil then lineageState = .array~new
  do revisionId over lineageState
    lineage~append(revisionId)
  end

  snapshot = .AlchemyNotNotesDocumentSnapshot~new(state["documentId"], state["formName"], -
      state["definitionIdentity"], fields, definitions, handlers, links, state["revision"], -
      state["revisionId"], lineage, state["lastWriterNode"])
  return .Document~fromSnapshot(snapshot)

/* Encode an immutable external payload, preserving arbitrary byte content as hex. */
::method encodeExternalDocument class
  use arg external
  snapshot = external~snapshot
  state = .directory~new
  state["externalId"] = snapshot~externalId
  state["displayName"] = snapshot~displayName
  state["mediaType"] = snapshot~mediaType
  state["sourceKind"] = snapshot~sourceKind
  if snapshot~content == .nil then state["contentHex"] = .nil
  else state["contentHex"] = c2x(snapshot~content~string)
  return state

::method decodeExternalDocument class
  use arg state
  content = .nil
  if state["contentHex"] \== .nil then content = x2c(state["contentHex"])
  return .AlchemyNotNotesExternalDocument~new(state["externalId"], state["displayName"], -
      state["mediaType"], content, state["sourceKind"])

/* Encode one field definition and its supported source contract. */
::method encodeField class
  use arg field
  state = .directory~new
  state["name"] = field~name
  source = field~source
  if source == .nil then do
    state["sourceKind"] = "NONE"
    return state
  end
  if source~isA(.AlchemyNotNotesFromReference) then do
    state["sourceKind"] = "REFERENCE"
    state["formName"] = source~typeFilter~formName
    return state
  end
  if source~isA(.AlchemyNotNotesFromExternalDocument) then do
    state["sourceKind"] = "EXTERNAL"
    state["mediaTypePrefix"] = source~mediaTypePrefix
    return state
  end
  raise syntax 93.900 array ("unsupported NotNotes RTO field source: " || field~name)

::method decodeField class
  use arg state
  kind = state["sourceKind"]
  source = .nil
  if kind = "REFERENCE" then source = .FromReference~new(.Document~type(state["formName"]))
  else if kind = "EXTERNAL" then source = .FromExternalDocument~new(state["mediaTypePrefix"])
  else if kind <> "NONE" then raise syntax 93.900 array ("unsupported NotNotes RTO field source kind: " || kind)
  return .Field~new(state["name"], source)

/* Encode supported document values without retaining live object authority. */
::method encodeValue class
  use arg value
  state = .directory~new
  if value == .nil then do
    state["kind"] = "NIL"
    return state
  end
  if value~isA(.AlchemyNotNotesApprovalSet) then do
    state["kind"] = "APPROVAL_SET"
    items = .array~new
    do item over value~snapshotItems
      itemState = .directory~new
      itemState["name"] = item~name
      itemState["outcome"] = item~outcome
      itemState["signed"] = item~signed
      itemState["evidence"] = self~encodeValue(item~evidence)
      items~append(itemState)
    end
    state["items"] = items
    return state
  end
  if value~isA(.AlchemyNotNotesReferralSet) then do
    state["kind"] = "REFERRAL_SET"
    items = .array~new
    do item over value~snapshotItems
      itemState = .directory~new
      itemState["targetIdentity"] = item~targetIdentity
      itemState["reason"] = item~reason
      itemState["status"] = item~status
      decision = item~decision
      if decision == .nil then itemState["decision"] = .nil
      else do
        decisionState = .directory~new
        decisionState["actorIdentity"] = decision~actorIdentity
        decisionState["outcome"] = decision~outcome
        decisionState["note"] = decision~note
        itemState["decision"] = decisionState
      end
      items~append(itemState)
    end
    state["items"] = items
    return state
  end
  if value~isA(.AlchemyNotNotesExternalDocumentLink) then do
    state["kind"] = "EXTERNAL_LINK"
    state["externalId"] = value~externalId
    state["displayName"] = value~displayName
    state["mediaType"] = value~mediaType
    return state
  end
  if value~isA(.AlchemyNotNotesDocumentReference) then do
    state["kind"] = "DOCUMENT_REFERENCE"
    state["documentId"] = value~documentId
    state["formName"] = value~formName
    return state
  end
  if value~isA(.Array) then do
    state["kind"] = "ARRAY"
    items = .array~new
    do item over value
      items~append(self~encodeValue(item))
    end
    state["items"] = items
    return state
  end
  if value~isA(.Directory) then do
    state["kind"] = "DIRECTORY"
    entries = .array~new
    keys = value~allIndexes
    do key over keys
      entry = .directory~new
      entry["keyHex"] = c2x(key~string)
      entry["value"] = self~encodeValue(value~at(key))
      entries~append(entry)
    end
    state["entries"] = entries
    return state
  end
  if value~isA(.String) then do
    state["kind"] = "STRING"
    state["hex"] = c2x(value~string)
    return state
  end
  raise syntax 93.900 array ("unsupported NotNotes RTO field value class: " || value~class~id)

::method decodeValue class
  use arg state
  kind = state["kind"]
  if kind = "NIL" then return .nil
  if kind = "STRING" then return x2c(state["hex"])
  if kind = "EXTERNAL_LINK" then
    return .ExternalDocumentLink~new(state["externalId"], state["displayName"], state["mediaType"])
  if kind = "DOCUMENT_REFERENCE" then
    return .DocumentReference~new(state["documentId"], state["formName"])
  if kind = "ARRAY" then do
    value = .array~new
    items = state["items"]
    if items == .nil then return value
    do itemState over items
      value~append(self~decodeValue(itemState))
    end
    return value
  end
  if kind = "DIRECTORY" then do
    value = .directory~new
    entries = state["entries"]
    if entries == .nil then return value
    do entry over entries
      value~put(self~decodeValue(entry["value"]), x2c(entry["keyHex"]))
    end
    return value
  end
  if kind = "APPROVAL_SET" then do
    value = .ApprovalSet~new
    items = state["items"]
    if items == .nil then return value
    do itemState over items
      value~evaluate(itemState["name"], itemState["outcome"], itemState["signed"], -
          self~decodeValue(itemState["evidence"]))
    end
    return value
  end
  if kind = "REFERRAL_SET" then do
    value = .ReferralSet~new
    items = state["items"]
    if items == .nil then return value
    do itemState over items
      item = value~refer(itemState["targetIdentity"], itemState["reason"])
      if itemState["status"] = "RESOLVED" then do
        decisionState = itemState["decision"]
        if decisionState == .nil then item~resolve
        else item~decide(decisionState["actorIdentity"], decisionState["outcome"], decisionState["note"])
      end
    end
    return value
  end
  raise syntax 93.900 array ("unsupported NotNotes RTO field value kind: " || kind)


::class AlchemyNotNotesReplicator public

/* Bind one source node and one target node for an explicit replication session. */
::method init
  expose source target
  use arg newSource, newTarget
  if newSource == .nil then raise syntax 93.900 array ("replicator requires source and target nodes")
  if newTarget == .nil then raise syntax 93.900 array ("replicator requires source and target nodes")
  source = newSource
  target = newTarget

::attribute source get
::attribute target get

/* Replicate the source node's current revision of one document to the target. */
::method replicateDocument
  expose source target
  use arg documentId
  document = source~document(documentId)
  if document == .nil then
    return .AlchemyNotNotesReplicationResult~new("NOT_FOUND", documentId)

  externalLinks = document~externalDocumentLinks
  do externalLink over externalLinks
    external = source~externalDocument(externalLink~externalId)
    if external == .nil then
      return .AlchemyNotNotesReplicationResult~new("REJECTED", "missing external document: " || externalLink~externalId)
    dependencyResult = target~receiveExternalSnapshot(external~snapshot)
    if dependencyResult~status = "CONFLICT" | dependencyResult~status = "REJECTED" then
      return .AlchemyNotNotesReplicationResult~new("REJECTED", dependencyResult~detail)
  end

  return target~receiveSnapshot(document~snapshot)

/* Replicate the source node's complete current document population. */
::method replicate
  expose source
  batch = .AlchemyNotNotesReplicationBatchResult~new
  ids = source~documentIds
  do documentId over ids
    batch~add(documentId, self~replicateDocument(documentId))
  end
  return batch

/* Create the reverse-direction session without altering this one. */
::method reverse
  expose source target
  return .AlchemyNotNotesReplicator~new(target, source)


::class AlchemyNotNotesReplicationResult public

/* Capture a small stable replication outcome contract. */
::method init
  expose status detail
  use arg newStatus, newDetail
  status = newStatus
  detail = newDetail

::attribute status get
::attribute detail get

/* True for outcomes that left the target containing the incoming revision. */
::method accepted
  expose status
  return status = "CREATED" | status = "UPDATED" | status = "UNCHANGED"


::class AlchemyNotNotesReplicationBatchResult public

/* Initialise a stable per-document result collection for population sync. */
::method init
  expose results
  results = .directory~new

/* Record one document replication result. */
::method add
  expose results
  use arg documentId, result
  results~put(result, documentId)
  return result

/* Fetch one document's replication result by durable identity. */
::method result
  expose results
  use arg documentId
  return results~at(documentId)

/* Return the number of documents considered by this replication pass. */
::method items
  expose results
  return results~items

/* Count outcomes with one status value. */
::method count
  expose results
  use arg wantedStatus
  total = 0
  indexes = results~allIndexes
  do documentId over indexes
    if results~at(documentId)~status = wantedStatus then total += 1
  end
  return total
