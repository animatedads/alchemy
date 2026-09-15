/*
 * X12NativeSource v0.4
 *
 * ooRexx-native X12 object model and selector engine.
 *
 * Design invariant: an interchange is retained as structured source objects.
 * Segments, elements and components preserve lexical form, decoded form,
 * source spans, hierarchy and envelope/transaction identity.  Relational values
 * are projections over these objects, never the native representation.
 */

::class X12ValidationFinding subclass RichSourceFinding public

::class X12BusinessFact subclass RichBusinessFact public
::method provenance
  p = .table~new
  p["source"] = self~source
  p["row"] = self~row
  p["createdAt"] = self~createdAt
  sourceObject = self~source
  if sourceObject \== .nil then do
    p["sourceProvenance"] = sourceObject~provenance
    p["document"] = sourceObject~document
    if sourceObject~hasMethod("TRANSACTION") then p["transaction"] = sourceObject~transaction
    if sourceObject~hasMethod("SEGMENT") then do
      p["segment"] = sourceObject~segment
      if sourceObject~segment~group \== .nil then p["group"] = sourceObject~segment~group
      if sourceObject~segment~interchange \== .nil then p["interchange"] = sourceObject~segment~interchange
    end
  end
  rowObject = self~row
  if rowObject \== .nil then do
    p["origin"] = rowObject~origin
    p["projection"] = rowObject~projection
  end
  return p


::class X12SourceSpan public
::attribute source get
::attribute startOffset get
::attribute endOffset get
::attribute startLine get
::attribute startColumn get
::attribute endLine get
::attribute endColumn get

::method init
  expose source startOffset endOffset startLine startColumn endLine endColumn
  use arg sourceArg, startOffsetArg, endOffsetArg, startLineArg, startColumnArg, endLineArg, endColumnArg
  source = sourceArg~string
  startOffset = startOffsetArg
  endOffset = endOffsetArg
  startLine = startLineArg
  startColumn = startColumnArg
  endLine = endLineArg
  endColumn = endColumnArg

::method string
  expose source startLine startColumn endLine endColumn
  return source || ":" || startLine || ":" || startColumn || "-" || endLine || ":" || endColumn


::class X12Separators public
::attribute component get
::attribute element get
::attribute repetition get
::attribute segment get
::attribute isaStart get
::attribute isaLexical get
::attribute interchangeVersion get

::method init
  expose component element repetition segment isaStart isaLexical interchangeVersion
  use arg componentArg = ":", elementArg = "*", repetitionArg = "^", segmentArg = "~", isaStartArg = 1, isaLexicalArg = "", versionArg = ""
  component = componentArg
  element = elementArg
  repetition = repetitionArg
  segment = segmentArg
  isaStart = isaStartArg
  isaLexical = isaLexicalArg
  interchangeVersion = versionArg

::method fromSource class
  use arg text
  startAt = 1
  do while startAt <= text~length
    ch = text~substr(startAt, 1)
    if ch = " " | ch = "09"x | ch = "0d"x | ch = "0a"x then startAt = startAt + 1
    else leave
  end
  if startAt > text~length - 105 then raise syntax 93.900 additional("X12 source is too short for a fixed-length ISA segment")
  if text~substr(startAt, 3) \= "ISA" then raise syntax 93.900 additional("X12 source must begin with ISA after leading whitespace")

  elementSep = text~substr(startAt + 3, 1)
  repetitionCandidate = text~substr(startAt + 82, 1)
  version = text~substr(startAt + 84, 5)
  componentSep = text~substr(startAt + 104, 1)
  segmentTerm = text~substr(startAt + 105, 1)
  repetitionSep = ""
  if datatype(version, "W") then do
    if version >= 402 then repetitionSep = repetitionCandidate
  end
  else repetitionSep = repetitionCandidate
  isaLexical = text~substr(startAt, 106)
  return self~new(componentSep, elementSep, repetitionSep, segmentTerm, startAt, isaLexical, version)

::method string
  expose component element repetition segment interchangeVersion
  return "X12-SEPARATORS(element=" || element || ",repetition=" || repetition || ",component=" || component || ",segment=" || segment || ",version=" || interchangeVersion || ")"


::class X12Component public
::attribute repetition get
::attribute position get
::attribute lexicalValue get
::attribute value get
::attribute span get

::method init
  expose repetition position lexicalValue value span
  use arg repetitionArg, positionArg, lexicalValueArg, valueArg, spanArg
  repetition = repetitionArg
  position = positionArg
  lexicalValue = lexicalValueArg
  value = valueArg
  span = spanArg

::method element
  expose repetition
  return repetition~element

::method document
  expose repetition
  return repetition~document

::method segment
  expose repetition
  return repetition~segment

::method transaction
  expose repetition
  return repetition~transaction

::method group
  expose repetition
  return repetition~segment~group

::method text
  expose value
  return value

::method scalarValue
  expose value
  return value

::method line
  expose span
  return span~startLine

::method path
  expose repetition position
  return repetition~path || "/C" || position

::method provenance
  expose repetition position lexicalValue value span
  p = .table~new
  p["kind"] = "X12_COMPONENT"
  p["document"] = self~document
  p["transaction"] = self~transaction
  p["group"] = self~group
  p["segment"] = self~segment
  p["element"] = repetition~element
  p["repetition"] = repetition
  p["componentPosition"] = position
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["lexicalValue"] = lexicalValue
  p["value"] = value
  return p

::method string
  expose value
  return value


::class X12Repetition public
::attribute element get
::attribute position get
::attribute lexicalValue get
::attribute span get
::attribute components get

::method init
  expose element position lexicalValue span components
  use arg elementArg, positionArg, lexicalValueArg, spanArg
  element = elementArg
  position = positionArg
  lexicalValue = lexicalValueArg
  span = spanArg
  components = .array~new

::method addComponent
  expose components
  use arg lexicalValue, value, span
  component = .X12Component~new(self, components~items + 1, lexicalValue, value, span)
  components~append(component)
  return component

::method component
  expose components
  use arg wantedPosition
  if wantedPosition < 1 then return .nil
  if wantedPosition > components~items then return .nil
  return components[wantedPosition]

::method document
  expose element
  return element~document

::method segment
  expose element
  return element~segment

::method transaction
  expose element
  return element~transaction

::method group
  expose element
  return element~segment~group

::method scalarValue
  expose components
  if components~items = 0 then return ""
  if components~items = 1 then return components[1]~value
  return .nil

::method line
  expose span
  return span~startLine

::method path
  expose element position
  return element~path || "/R" || position

::method provenance
  expose element position lexicalValue span components
  p = .table~new
  p["kind"] = "X12_REPETITION"
  p["document"] = self~document
  p["transaction"] = self~transaction
  p["group"] = self~group
  p["segment"] = self~segment
  p["element"] = element
  p["repetitionPosition"] = position
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["lexicalValue"] = lexicalValue
  p["components"] = components
  return p

::method string
  expose components position
  if components~items = 1 then return components[1]~string
  return "X12-REPETITION(R" || position || ",components=" || components~items || ")"


::class X12Element public
::attribute segment get
::attribute position get
::attribute lexicalValue get
::attribute span get
::attribute repetitions get

::method init
  expose segment position lexicalValue span repetitions
  use arg segmentArg, positionArg, lexicalValueArg, spanArg
  segment = segmentArg
  position = positionArg
  lexicalValue = lexicalValueArg
  span = spanArg
  repetitions = .array~new

::method addRepetition
  expose repetitions
  use arg lexicalValue, span
  repetition = .X12Repetition~new(self, repetitions~items + 1, lexicalValue, span)
  repetitions~append(repetition)
  return repetition

::method repetition
  expose repetitions
  use arg wantedPosition
  if wantedPosition < 1 then return .nil
  if wantedPosition > repetitions~items then return .nil
  return repetitions[wantedPosition]

::method components
  expose repetitions
  if repetitions~items = 0 then return .array~new
  return repetitions[1]~components

::method component
  expose repetitions
  use arg wantedPosition
  if repetitions~items = 0 then return .nil
  return repetitions[1]~component(wantedPosition)

::method document
  expose segment
  return segment~document

::method transaction
  expose segment
  return segment~transaction

::method group
  expose segment
  return segment~group

::method scalarValue
  expose repetitions
  if repetitions~items = 0 then return ""
  if repetitions~items > 1 then return .nil
  return repetitions[1]~scalarValue

::method text
  return self~scalarValue

::method isComposite
  expose repetitions
  if repetitions~items <> 1 then return .true
  return repetitions[1]~components~items > 1

::method isRepeated
  expose repetitions
  return repetitions~items > 1

::method line
  expose span
  return span~startLine

::method path
  expose segment position
  return segment~path || "/E" || position

::method provenance
  expose segment position lexicalValue span repetitions
  p = .table~new
  p["kind"] = "X12_ELEMENT"
  p["document"] = self~document
  p["transaction"] = self~transaction
  p["group"] = self~group
  p["segment"] = segment
  p["elementPosition"] = position
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["lexicalValue"] = lexicalValue
  p["repetitions"] = repetitions
  return p

::method string
  expose repetitions position
  if repetitions~items = 1 then do
    if repetitions[1]~components~items = 1 then return repetitions[1]~components[1]~string
  end
  return "X12-ELEMENT(E" || position || ",repetitions=" || repetitions~items || ")"


::class X12Segment public
::attribute document get
::attribute tag get
::attribute lexicalValue get
::attribute span get
::attribute ordinal get
::attribute elements get
::attribute transaction
::attribute group
::attribute interchange

::method init
  expose document tag lexicalValue span ordinal elements transaction group interchange
  use arg documentArg, tagArg, lexicalValueArg, spanArg, ordinalArg
  document = documentArg
  tag = tagArg~string~translate
  lexicalValue = lexicalValueArg
  span = spanArg
  ordinal = ordinalArg
  elements = .array~new
  transaction = .nil
  group = .nil
  interchange = .nil

::method addElement
  expose elements
  use arg lexicalValue, span
  element = .X12Element~new(self, elements~items + 1, lexicalValue, span)
  elements~append(element)
  return element

::method element
  expose elements
  use arg wantedPosition
  if wantedPosition < 1 then return .nil
  if wantedPosition > elements~items then return .nil
  return elements[wantedPosition]

::method scalarValue
  return .nil

::method line
  expose span
  return span~startLine

::method occurrence
  expose document tag ordinal
  count = 0
  do segment over document~segments
    if segment~tag = tag then count = count + 1
    if segment == self then return count
  end
  return ordinal

::method transactionOccurrence
  expose transaction tag
  if transaction == .nil then return self~occurrence
  count = 0
  do segment over transaction~segments
    if segment~tag = tag then count = count + 1
    if segment == self then return count
  end
  return count

::method path
  expose tag transaction group interchange
  suffix = tag || "[" || self~transactionOccurrence || "]"
  if transaction \== .nil then return transaction~path || "/" || suffix
  if group \== .nil then return group~path || "/" || suffix
  if interchange \== .nil then return interchange~path || "/" || suffix
  return "/" || suffix

::method provenance
  expose document tag lexicalValue span ordinal elements transaction group interchange
  p = .table~new
  p["kind"] = "X12_SEGMENT"
  p["document"] = document
  p["transaction"] = transaction
  p["group"] = group
  p["interchange"] = interchange
  p["tag"] = tag
  p["ordinal"] = ordinal
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["lexicalValue"] = lexicalValue
  p["elements"] = elements
  return p

::method string
  expose tag ordinal
  return "X12-SEGMENT(" || tag || "#" || ordinal || ")"


::class X12TransactionSet public
::attribute document get
::attribute interchange
::attribute group
::attribute ordinal get
::attribute segments get
::attribute header
::attribute trailer
::attribute controlNumber get
::attribute transactionSetId get
::attribute implementationConvention get
::attribute span

::method init
  expose document interchange group ordinal segments header trailer controlNumber transactionSetId implementationConvention span
  use arg documentArg, ordinalArg
  document = documentArg
  ordinal = ordinalArg
  interchange = .nil
  group = .nil
  segments = .array~new
  header = .nil
  trailer = .nil
  controlNumber = ""
  transactionSetId = ""
  implementationConvention = ""
  span = .nil

::method addSegment
  expose segments header trailer controlNumber transactionSetId implementationConvention
  use arg segment
  segments~append(segment)
  segment~transaction = self
  if segment~tag = "ST" then do
    header = segment
    e = segment~element(1)
    if e \== .nil then do
      v = e~scalarValue
      if v \== .nil then transactionSetId = v~translate
    end
    e = segment~element(2)
    if e \== .nil then do
      v = e~scalarValue
      if v \== .nil then controlNumber = v
    end
    e = segment~element(3)
    if e \== .nil then do
      v = e~scalarValue
      if v \== .nil then implementationConvention = v
    end
  end
  if segment~tag = "SE" then trailer = segment
  return segment

::method segmentSelection
  expose segments
  use arg tagArg, occurrenceArg = 0, qualifierArg = .nil
  wantedTag = tagArg~string~translate
  selected = .array~new
  do segment over segments
    if segment~tag \= wantedTag then iterate
    if qualifierArg \== .nil then do
      firstElement = segment~element(1)
      if firstElement == .nil then iterate
      qualifier = firstElement~scalarValue
      if qualifier == .nil then do
        firstComponent = firstElement~component(1)
        if firstComponent == .nil then iterate
        qualifier = firstComponent~value
      end
      if qualifier \== qualifierArg~string then iterate
    end
    selected~append(segment)
  end
  if occurrenceArg > 0 then do
    one = .array~new
    if occurrenceArg <= selected~items then one~append(selected[occurrenceArg])
    return one
  end
  return selected

::method sourceForReference
  expose header
  if header == .nil then return .nil
  return header~element(2)

::method sourceForType
  expose header
  if header == .nil then return .nil
  return header~element(1)

::method sourceForImplementation
  expose header
  if header == .nil then return .nil
  return header~element(3)

::method sourceForVersion
  expose group
  if group == .nil then return .nil
  return group~sourceForVersion

::method line
  expose header
  if header == .nil then return 0
  return header~line

::method path
  expose group interchange ordinal
  if group \== .nil then return group~path || "/TRANSACTION[" || ordinal || "]"
  if interchange \== .nil then return interchange~path || "/TRANSACTION[" || ordinal || "]"
  return "/TRANSACTION[" || ordinal || "]"

::method provenance
  expose document interchange group ordinal segments header trailer controlNumber transactionSetId implementationConvention
  p = .table~new
  p["kind"] = "X12_TRANSACTION"
  p["document"] = document
  p["interchange"] = interchange
  p["group"] = group
  p["ordinal"] = ordinal
  p["path"] = self~path
  p["controlNumber"] = controlNumber
  p["transactionSetId"] = transactionSetId
  p["implementationConvention"] = implementationConvention
  p["segments"] = segments
  return p

::method string
  expose controlNumber transactionSetId
  return "X12-TRANSACTION(" || transactionSetId || "," || controlNumber || ")"


::class X12FunctionalGroup public
::attribute document get
::attribute interchange
::attribute ordinal get
::attribute segments get
::attribute transactions get
::attribute header
::attribute trailer
::attribute functionalCode get
::attribute senderCode get
::attribute receiverCode get
::attribute groupDate get
::attribute groupTime get
::attribute controlNumber get
::attribute responsibleAgencyCode get
::attribute version get

::method init
  expose document interchange ordinal segments transactions header trailer functionalCode senderCode receiverCode groupDate groupTime controlNumber responsibleAgencyCode version
  use arg documentArg, ordinalArg
  document = documentArg
  ordinal = ordinalArg
  interchange = .nil
  segments = .array~new
  transactions = .array~new
  header = .nil
  trailer = .nil
  functionalCode = ""
  senderCode = ""
  receiverCode = ""
  groupDate = ""
  groupTime = ""
  controlNumber = ""
  responsibleAgencyCode = ""
  version = ""

::method addSegment
  expose segments header trailer functionalCode senderCode receiverCode groupDate groupTime controlNumber responsibleAgencyCode version
  use arg segment
  segments~append(segment)
  segment~group = self
  if segment~tag = "GS" then do
    header = segment
    e = segment~element(1); if e \== .nil then do; v=e~scalarValue; if v \== .nil then functionalCode=v~translate; end
    e = segment~element(2); if e \== .nil then do; v=e~scalarValue; if v \== .nil then senderCode=v; end
    e = segment~element(3); if e \== .nil then do; v=e~scalarValue; if v \== .nil then receiverCode=v; end
    e = segment~element(4); if e \== .nil then do; v=e~scalarValue; if v \== .nil then groupDate=v; end
    e = segment~element(5); if e \== .nil then do; v=e~scalarValue; if v \== .nil then groupTime=v; end
    e = segment~element(6); if e \== .nil then do; v=e~scalarValue; if v \== .nil then controlNumber=v; end
    e = segment~element(7); if e \== .nil then do; v=e~scalarValue; if v \== .nil then responsibleAgencyCode=v; end
    e = segment~element(8); if e \== .nil then do; v=e~scalarValue; if v \== .nil then version=v; end
  end
  if segment~tag = "GE" then trailer = segment
  return segment

::method addTransaction
  expose transactions interchange
  use arg transaction
  transactions~append(transaction)
  transaction~group = self
  transaction~interchange = interchange
  return transaction

::method sourceForVersion
  expose header
  if header == .nil then return .nil
  return header~element(8)

::method sourceForControl
  expose header
  if header == .nil then return .nil
  return header~element(6)

::method path
  expose interchange ordinal
  if interchange \== .nil then return interchange~path || "/GROUP[" || ordinal || "]"
  return "/GROUP[" || ordinal || "]"

::method provenance
  expose document interchange ordinal segments transactions header trailer functionalCode senderCode receiverCode groupDate groupTime controlNumber responsibleAgencyCode version
  p=.table~new
  p["kind"]="X12_FUNCTIONAL_GROUP"
  p["document"]=document
  p["interchange"]=interchange
  p["ordinal"]=ordinal
  p["path"]=self~path
  p["functionalCode"]=functionalCode
  p["senderCode"]=senderCode
  p["receiverCode"]=receiverCode
  p["controlNumber"]=controlNumber
  p["version"]=version
  p["segments"]=segments
  p["transactions"]=transactions
  return p

::method string
  expose functionalCode controlNumber
  return "X12-GROUP(" || functionalCode || "," || controlNumber || ")"


::class X12Interchange public
::attribute document get
::attribute ordinal get
::attribute segments get
::attribute groups get
::attribute transactions get
::attribute header
::attribute trailer
::attribute controlNumber get
::attribute version get
::attribute senderId get
::attribute receiverId get

::method init
  expose document ordinal segments groups transactions header trailer controlNumber version senderId receiverId
  use arg documentArg, ordinalArg
  document = documentArg
  ordinal = ordinalArg
  segments = .array~new
  groups = .array~new
  transactions = .array~new
  header = .nil
  trailer = .nil
  controlNumber = ""
  version = ""
  senderId = ""
  receiverId = ""

::method addSegment
  expose segments header trailer controlNumber version senderId receiverId
  use arg segment
  segments~append(segment)
  segment~interchange = self
  if segment~tag = "ISA" then do
    header = segment
    e=segment~element(6); if e \== .nil then do; v=e~scalarValue; if v \== .nil then senderId=v~strip; end
    e=segment~element(8); if e \== .nil then do; v=e~scalarValue; if v \== .nil then receiverId=v~strip; end
    e=segment~element(12); if e \== .nil then do; v=e~scalarValue; if v \== .nil then version=v; end
    e=segment~element(13); if e \== .nil then do; v=e~scalarValue; if v \== .nil then controlNumber=v; end
  end
  if segment~tag = "IEA" then trailer = segment
  return segment

::method addGroup
  expose groups
  use arg group
  groups~append(group)
  group~interchange = self
  return group

::method addTransaction
  expose transactions
  use arg transaction
  transactions~append(transaction)
  transaction~interchange = self
  return transaction

::method sourceForControl
  expose header
  if header == .nil then return .nil
  return header~element(13)

::method path
  expose ordinal
  return "/INTERCHANGE[" || ordinal || "]"

::method provenance
  expose document ordinal segments groups transactions header trailer controlNumber version senderId receiverId
  p=.table~new
  p["kind"]="X12_INTERCHANGE"
  p["document"]=document
  p["ordinal"]=ordinal
  p["path"]=self~path
  p["controlNumber"]=controlNumber
  p["version"]=version
  p["senderId"]=senderId
  p["receiverId"]=receiverId
  p["segments"]=segments
  p["groups"]=groups
  p["transactions"]=transactions
  return p

::method string
  expose ordinal controlNumber
  return "X12-INTERCHANGE(" || ordinal || "," || controlNumber || ")"


::class X12Selection public
::attribute document get
::attribute expression get
::attribute context get
::attribute nodes get
::attribute kind get
::attribute value get
::attribute createdAt get

::method init
  expose document expression context nodes kind value createdAt
  use arg documentArg, expressionArg, contextArg, nodesArg = .nil, kindArg = "NODESET", valueArg = .nil
  document = documentArg
  expression = expressionArg~string
  context = contextArg
  if nodesArg == .nil then nodes = .array~new
  else nodes = nodesArg
  kind = kindArg~string~translate
  value = valueArg
  createdAt = .DateTime~new~utcIsoDate

::method count
  expose kind nodes value
  if kind = "NODESET" then return nodes~items
  if value == .nil then return 0
  return 1

::method firstNode
  expose kind nodes
  if kind \= "NODESET" then return .nil
  if nodes~items = 0 then return .nil
  return nodes[1]

::method scalar
  expose kind nodes value
  if kind \= "NODESET" then return value
  if nodes~items = 0 then return .nil
  if nodes~items > 1 then return .nil
  node = nodes[1]
  return node~scalarValue

::method provenance
  expose document expression context nodes kind createdAt
  p = .table~new
  p["kind"] = "X12_SELECTION"
  p["document"] = document
  p["expression"] = expression
  p["context"] = context
  p["selectionKind"] = kind
  p["nodes"] = nodes
  p["createdAt"] = createdAt
  return p

::method string
  expose kind nodes value
  if kind = "NODESET" then return "X12-NODESET(" || nodes~items || ")"
  if value == .nil then return "X12-SCALAR(NIL)"
  return "X12-SCALAR"


::class X12ValidationReport public
::attribute name get
::attribute document get
::attribute findings get
::attribute startedAt get
::attribute completedAt get
::attribute status get

::method init
  expose name document findings startedAt completedAt status
  use arg nameArg, documentArg
  name = nameArg~string
  document = documentArg
  findings = .array~new
  startedAt = .DateTime~new~utcIsoDate
  completedAt = ""
  status = "RUNNING"

::method addFinding
  expose findings document
  use arg finding
  findings~append(finding)
  document~addFinding(finding)
  return finding

::method complete
  expose findings completedAt status
  completedAt = .DateTime~new~utcIsoDate
  status = "VALID"
  do finding over findings
    if finding~severity = "ERROR" then status = "INVALID"
  end
  return self

::method string
  expose name status findings
  return "X12-VALIDATION(" || name || "," || status || ",findings=" || findings~items || ")"


::class X12DocumentContext public
::attribute source get
::attribute sourceText get
::attribute separators get
::attribute segments get
::attribute interchanges get
::attribute groups get
::attribute transactions get
::attribute history get
::attribute validationFindings get
::attribute validationReports get
::attribute metadata get
::attribute openedAt get
::attribute parserName get
::attribute closed get
::attribute lineStarts get

::method init
  expose source sourceText separators segments interchanges groups transactions history validationFindings validationReports metadata openedAt parserName closed lineStarts
  use arg sourceArg, textArg = .nil
  source = sourceArg~string
  sourceText = textArg
  if sourceText == .nil then sourceText = self~readSource(source)
  separators = .X12Separators~fromSource(sourceText)
  segments = .array~new
  interchanges = .array~new
  groups = .array~new
  transactions = .array~new
  history = .array~new
  validationFindings = .array~new
  validationReports = .array~new
  metadata = .table~new
  openedAt = .DateTime~new~utcIsoDate
  parserName = "OOREXX_NATIVE_X12_V0.4"
  closed = .false
  lineStarts = self~buildLineStarts(sourceText)
  parser = .X12NativeParser~new(self, sourceText, separators)
  parser~parse
  history~append(.RichProcessingEvent~new("PARSE", "OOREXX_NATIVE_X12", source, self))

::method fromText class
  use arg text, source = "memory:x12"
  return self~new(source, text)

::method readSource private
  use arg sourcePath
  s = .stream~new(sourcePath)
  openStatus = s~open("READ")
  if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Unable to open X12 source:" sourcePath || " status=" || openStatus)
  available = s~chars
  data = s~charin(1, available)
  closeStatus = s~close
  return data

::method buildLineStarts private
  use arg text
  starts = .array~new
  starts~append(1)
  do i = 1 to text~length
    if text~substr(i, 1) = "0a"x then do
      if i < text~length then starts~append(i + 1)
    end
  end
  return starts

::method lineColumnAt
  expose lineStarts sourceText
  use arg offset
  if offset < 1 then offset = 1
  if offset > sourceText~length + 1 then offset = sourceText~length + 1
  lineNo = 1
  lineStart = 1
  do i = 1 to lineStarts~items
    candidate = lineStarts[i]
    if candidate > offset then leave
    lineNo = i
    lineStart = candidate
  end
  resultPair = .array~new
  resultPair~append(lineNo)
  resultPair~append(offset - lineStart + 1)
  return resultPair

::method span
  expose source
  use arg startOffset, endOffset
  startLC = self~lineColumnAt(startOffset)
  endLC = self~lineColumnAt(endOffset)
  return .X12SourceSpan~new(source, startOffset, endOffset, startLC[1], startLC[2], endLC[1], endLC[2])

::method addSegment
  expose segments
  use arg segment
  segments~append(segment)
  return segment

::method addInterchange
  expose interchanges
  use arg interchange
  interchanges~append(interchange)
  return interchange

::method addGroup
  expose groups
  use arg group
  groups~append(group)
  return group

::method addTransaction
  expose transactions
  use arg transaction
  transactions~append(transaction)
  return transaction

::method select
  expose history
  use arg expression, context = .nil
  selection = .X12SelectorEngine~evaluate(self, expression~string, context)
  history~append(.RichProcessingEvent~new("SELECT", "X12_SELECTOR", expression~string, selection))
  return selection

::method addFinding
  expose validationFindings
  use arg finding
  validationFindings~append(finding)
  return finding

::method validateEnvelope
  expose validationReports history
  report = .X12EnvelopeValidator~validate(self)
  validationReports~append(report)
  history~append(.RichProcessingEvent~new("VALIDATE", "X12_ENVELOPE", report~status, report))
  return report

::method close
  expose closed history source
  if closed then return .true
  closed = .true
  history~append(.RichProcessingEvent~new("LIFECYCLE", "CLOSE", source, self))
  return .true

::method string
  expose source parserName
  return "X12-DOCUMENT(" || parserName || "," || source || ")"


::class X12NativeParser public
::attribute document get
::attribute text get
::attribute separators get

::method init
  expose document text separators
  use arg documentArg, textArg, separatorsArg
  document = documentArg
  text = textArg
  separators = separatorsArg

::method parse
  expose document text separators
  currentInterchange = .nil
  currentGroup = .nil
  currentTransaction = .nil
  position = separators~isaStart

  do while position <= text~length
    do while position <= text~length
      ch = text~substr(position, 1)
      if ch = " " | ch = "09"x | ch = "0d"x | ch = "0a"x then position = position + 1
      else leave
    end
    if position > text~length then leave

    segmentStart = position
    segmentEnd = text~pos(separators~segment, segmentStart)
    if segmentEnd = 0 then segmentEnd = text~length + 1
    rawEnd = segmentEnd - 1
    if rawEnd < segmentStart then raw = ""
    else raw = text~substr(segmentStart, rawEnd - segmentStart + 1)

    if raw <> "" then do
      segment = self~parseSegment(raw, segmentStart, segmentEnd)
      document~addSegment(segment)

      if segment~tag = "ISA" then do
        currentInterchange = .X12Interchange~new(document, document~interchanges~items + 1)
        document~addInterchange(currentInterchange)
        currentInterchange~addSegment(segment)
      end
      else if currentInterchange \== .nil then currentInterchange~addSegment(segment)

      if segment~tag = "GS" then do
        currentGroup = .X12FunctionalGroup~new(document, document~groups~items + 1)
        document~addGroup(currentGroup)
        if currentInterchange \== .nil then currentInterchange~addGroup(currentGroup)
        currentGroup~addSegment(segment)
      end
      else if currentGroup \== .nil then currentGroup~addSegment(segment)

      if segment~tag = "ST" then do
        currentTransaction = .X12TransactionSet~new(document, document~transactions~items + 1)
        document~addTransaction(currentTransaction)
        if currentGroup \== .nil then currentGroup~addTransaction(currentTransaction)
        if currentInterchange \== .nil then currentInterchange~addTransaction(currentTransaction)
        currentTransaction~addSegment(segment)
      end
      else if currentTransaction \== .nil then currentTransaction~addSegment(segment)

      if segment~tag = "SE" then currentTransaction = .nil
      if segment~tag = "GE" then currentGroup = .nil
      if segment~tag = "IEA" then currentInterchange = .nil
    end

    if segmentEnd > text~length then leave
    position = segmentEnd + 1
  end
  return document

::method parseSegment private
  expose document separators
  use arg raw, absoluteStart, terminatorOffset
  tokens = self~splitPreserve(raw, separators~element, absoluteStart)
  if tokens~items = 0 then raise syntax 93.900 additional("Empty X12 segment")
  tagToken = tokens[1]
  tag = tagToken["text"]~strip~translate
  segmentSpan = document~span(absoluteStart, terminatorOffset)
  segment = .X12Segment~new(document, tag, raw || separators~segment, segmentSpan, document~segments~items + 1)

  do tokenIndex = 2 to tokens~items
    token = tokens[tokenIndex]
    elementSpan = document~span(token["start"], token["end"])
    element = segment~addElement(token["text"], elementSpan)
    if tag = "ISA" | separators~repetition = "" then repetitions = self~singleToken(token["text"], token["start"])
    else repetitions = self~splitPreserve(token["text"], separators~repetition, token["start"])
    do repetitionToken over repetitions
      repetitionSpan = document~span(repetitionToken["start"], repetitionToken["end"])
      repetition = element~addRepetition(repetitionToken["text"], repetitionSpan)
      if tag = "ISA" then components = self~singleToken(repetitionToken["text"], repetitionToken["start"])
      else components = self~splitPreserve(repetitionToken["text"], separators~component, repetitionToken["start"])
      do componentToken over components
        componentSpan = document~span(componentToken["start"], componentToken["end"])
        repetition~addComponent(componentToken["text"], componentToken["text"], componentSpan)
      end
    end
  end
  return segment

::method singleToken private
  use arg sourceText, absoluteStart
  tokens = .array~new
  token = .table~new
  token["text"] = sourceText
  token["start"] = absoluteStart
  token["end"] = absoluteStart + sourceText~length - 1
  if token["end"] < token["start"] then token["end"] = token["start"]
  tokens~append(token)
  return tokens

::method splitPreserve private
  use arg sourceText, delimiter, absoluteStart
  tokens = .array~new
  if delimiter = "" then return self~singleToken(sourceText, absoluteStart)
  tokenStart = 1
  do i = 1 to sourceText~length + 1
    if i > sourceText~length | sourceText~substr(i, 1) = delimiter then do
      token = .table~new
      token["text"] = sourceText~substr(tokenStart, i - tokenStart)
      token["start"] = absoluteStart + tokenStart - 1
      token["end"] = absoluteStart + i - 2
      if token["end"] < token["start"] then token["end"] = token["start"]
      tokens~append(token)
      tokenStart = i + 1
    end
  end
  return tokens


::class X12SelectorEngine public

::method evaluate class
  use arg document, expression, context = .nil
  expr = expression~strip
  if expr = "" then return .X12Selection~new(document, expr, context)

  if context == .nil then do
    if expr~left(12)~caselessEquals("TRANSACTION:") then do
      wantedType = expr~substr(13)~strip~translate
      selected = .array~new
      do transaction over document~transactions
        if transaction~transactionSetId = wantedType then selected~append(transaction)
      end
      return .X12Selection~new(document, expr, document, selected)
    end
    if expr~caselessEquals("TRANSACTION") then return .X12Selection~new(document, expr, document, document~transactions~copy)
    if expr~left(6)~caselessEquals("GROUP:") then do
      wantedCode = expr~substr(7)~strip~translate
      selected = .array~new
      do group over document~groups
        if group~functionalCode = wantedCode then selected~append(group)
      end
      return .X12Selection~new(document, expr, document, selected)
    end
    if expr~caselessEquals("GROUP") then return .X12Selection~new(document, expr, document, document~groups~copy)
    if expr~caselessEquals("INTERCHANGE") then return .X12Selection~new(document, expr, document, document~interchanges~copy)
    if expr~left(8)~caselessEquals("SEGMENT:") then do
      wantedTag = expr~substr(9)~strip~translate
      selected = .array~new
      do segment over document~segments
        if segment~tag = wantedTag then selected~append(segment)
      end
      return .X12Selection~new(document, expr, document, selected)
    end
    raise syntax 93.900 additional("Unsupported X12 document selector:" expr)
  end

  if context~isA(.X12TransactionSet) then return self~fromTransaction(document, expr, context)
  if context~isA(.X12FunctionalGroup) then return self~fromGroup(document, expr, context)
  if context~isA(.X12Segment) then return self~fromSegment(document, expr, context)
  if context~isA(.X12Element) then return self~fromElement(document, expr, context)
  raise syntax 93.900 additional("Unsupported X12 selector context for:" expr)

::method fromTransaction class private
  use arg document, expr, transaction
  if expr~left(1) = "@" then do
    attr = expr~substr(2)~translate
    selected = .array~new
    select
      when attr = "REFERENCE" then source = transaction~sourceForReference
      when attr = "CONTROL" then source = transaction~sourceForReference
      when attr = "TYPE" then source = transaction~sourceForType
      when attr = "IMPLEMENTATION" then source = transaction~sourceForImplementation
      when attr = "VERSION" then source = transaction~sourceForVersion
      otherwise raise syntax 93.900 additional("Unsupported X12 transaction attribute selector:" expr)
    end
    if source \== .nil then selected~append(source)
    return .X12Selection~new(document, expr, transaction, selected)
  end

  slash = expr~pos("/")
  if slash = 0 then do
    segmentSpec = expr
    remainder = ""
  end
  else do
    segmentSpec = expr~substr(1, slash - 1)
    remainder = expr~substr(slash + 1)
  end
  parsed = self~parseSegmentSpec(segmentSpec)
  selectedSegments = transaction~segmentSelection(parsed["tag"], parsed["occurrence"], parsed["qualifier"])
  if remainder = "" then return .X12Selection~new(document, expr, transaction, selectedSegments)
  return self~descendSegments(document, expr, transaction, selectedSegments, remainder)

::method fromGroup class private
  use arg document, expr, group
  if expr~left(1) = "@" then do
    attr = expr~substr(2)~translate
    selected = .array~new
    select
      when attr = "FUNCTIONALCODE" then source = group~header~element(1)
      when attr = "CONTROL" then source = group~sourceForControl
      when attr = "VERSION" then source = group~sourceForVersion
      otherwise raise syntax 93.900 additional("Unsupported X12 group attribute selector:" expr)
    end
    if source \== .nil then selected~append(source)
    return .X12Selection~new(document, expr, group, selected)
  end
  if expr~left(12)~caselessEquals("TRANSACTION:") then do
    wantedType = expr~substr(13)~strip~translate
    selected = .array~new
    do transaction over group~transactions
      if transaction~transactionSetId = wantedType then selected~append(transaction)
    end
    return .X12Selection~new(document, expr, group, selected)
  end
  if expr~caselessEquals("TRANSACTION") then return .X12Selection~new(document, expr, group, group~transactions~copy)
  raise syntax 93.900 additional("Unsupported X12 group selector:" expr)

::method fromSegment class private
  use arg document, expr, segment
  if expr~left(1) = "@" then do
    attr = expr~substr(2)~translate
    select
      when attr = "TAG" then source = segment
      when attr = "ORDINAL" then return .X12Selection~new(document, expr, segment, .nil, "SCALAR", segment~ordinal)
      when attr = "TRANSACTIONCONTROL" then do
        if segment~transaction == .nil then return .X12Selection~new(document, expr, segment)
        selected = .array~new
        source = segment~transaction~sourceForReference
        if source \== .nil then selected~append(source)
        return .X12Selection~new(document, expr, segment, selected)
      end
      when attr = "TRANSACTIONTYPE" then do
        if segment~transaction == .nil then return .X12Selection~new(document, expr, segment)
        selected = .array~new
        source = segment~transaction~sourceForType
        if source \== .nil then selected~append(source)
        return .X12Selection~new(document, expr, segment, selected)
      end
      otherwise raise syntax 93.900 additional("Unsupported X12 segment attribute selector:" expr)
    end
    return .X12Selection~new(document, expr, segment, .nil, "SCALAR", source~tag)
  end

  parts = self~numericPath(expr)
  element = segment~element(parts["element"])
  selected = .array~new
  if element == .nil then return .X12Selection~new(document, expr, segment, selected)
  if parts["explicitRepetition"] then do
    repetition = element~repetition(parts["repetition"])
    if repetition == .nil then return .X12Selection~new(document, expr, segment, selected)
    if parts["component"] = 0 then selected~append(repetition)
    else do
      component = repetition~component(parts["component"])
      if component \== .nil then selected~append(component)
    end
  end
  else if parts["component"] = 0 then selected~append(element)
  else do
    component = element~component(parts["component"])
    if component \== .nil then selected~append(component)
  end
  return .X12Selection~new(document, expr, segment, selected)

::method fromElement class private
  use arg document, expr, element
  if \datatype(expr, "W") then raise syntax 93.900 additional("X12 element selector must be component position:" expr)
  selected = .array~new
  component = element~component(expr)
  if component \== .nil then selected~append(component)
  return .X12Selection~new(document, expr, element, selected)

::method descendSegments class private
  use arg document, expr, context, segments, remainder
  parts = self~numericPath(remainder)
  selected = .array~new
  do segment over segments
    element = segment~element(parts["element"])
    if element == .nil then iterate
    if parts["explicitRepetition"] then do
      repetition = element~repetition(parts["repetition"])
      if repetition == .nil then iterate
      if parts["component"] = 0 then selected~append(repetition)
      else do
        component = repetition~component(parts["component"])
        if component \== .nil then selected~append(component)
      end
    end
    else if parts["component"] = 0 then selected~append(element)
    else do
      component = element~component(parts["component"])
      if component \== .nil then selected~append(component)
    end
  end
  return .X12Selection~new(document, expr, context, selected)

::method numericPath class private
  use arg text
  parsed = .table~new
  parsed["element"] = 0
  parsed["repetition"] = 1
  parsed["explicitRepetition"] = .false
  parsed["component"] = 0

  slash = text~pos("/")
  if slash = 0 then first = text
  else do
    first = text~substr(1, slash - 1)
    second = text~substr(slash + 1)
    if \datatype(second, "W") then raise syntax 93.900 additional("X12 selector expected component position:" second)
    parsed["component"] = second
  end

  openBrace = first~pos("{")
  if openBrace = 0 then elementText = first
  else do
    closeBrace = first~lastPos("}")
    if closeBrace <= openBrace then raise syntax 93.900 additional("Malformed X12 repetition selector:" first)
    elementText = first~substr(1, openBrace - 1)
    repetitionText = first~substr(openBrace + 1, closeBrace - openBrace - 1)
    if \datatype(repetitionText, "W") then raise syntax 93.900 additional("X12 repetition must be numeric:" repetitionText)
    parsed["repetition"] = repetitionText
    parsed["explicitRepetition"] = .true
  end
  if \datatype(elementText, "W") then raise syntax 93.900 additional("X12 selector expected element position:" elementText)
  parsed["element"] = elementText
  return parsed


::method parseSegmentSpec class private
  use arg spec
  parsed = .table~new
  parsed["tag"] = spec~translate
  parsed["occurrence"] = 0
  parsed["qualifier"] = .nil
  openBracket = spec~pos("[")
  if openBracket = 0 then return parsed
  closeBracket = spec~lastPos("]")
  if closeBracket <= openBracket then raise syntax 93.900 additional("Malformed X12 segment selector:" spec)
  parsed["tag"] = spec~substr(1, openBracket - 1)~translate
  predicate = spec~substr(openBracket + 1, closeBracket - openBracket - 1)
  if predicate~left(1) = "=" then parsed["qualifier"] = predicate~substr(2)
  else do
    if \datatype(predicate, "W") then raise syntax 93.900 additional("X12 segment occurrence must be numeric:" predicate)
    parsed["occurrence"] = predicate
  end
  return parsed


::class X12EnvelopeValidator public

::method validate class
  use arg document
  report = .X12ValidationReport~new("X12_ENVELOPE", document)

  do transaction over document~transactions
    if transaction~header == .nil then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.TRANSACTION.ST.MISSING", "Transaction has no ST header", transaction, "X12_ENVELOPE"))
    if transaction~trailer == .nil then do
      report~addFinding(.X12ValidationFinding~new("ERROR", "X12.TRANSACTION.SE.MISSING", "Transaction " || transaction~controlNumber || " has no SE trailer", transaction, "X12_ENVELOPE"))
      iterate
    end
    countElement = transaction~trailer~element(1)
    if countElement \== .nil then do
      expectedText = countElement~scalarValue
      if expectedText \== .nil then do
        if datatype(expectedText, "W") then do
          actualCount = transaction~segments~items
          if expectedText \= actualCount then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.TRANSACTION.SEGMENT_COUNT", "SE declares " || expectedText || " segments but transaction contains " || actualCount, countElement, "X12_ENVELOPE"))
        end
        else report~addFinding(.X12ValidationFinding~new("ERROR", "X12.TRANSACTION.SEGMENT_COUNT.TYPE", "SE segment count is not an integer: " || expectedText, countElement, "X12_ENVELOPE"))
      end
    end
    trailerControl = transaction~trailer~element(2)
    if trailerControl \== .nil then do
      v = trailerControl~scalarValue
      if v \== .nil then do
        if v \== transaction~controlNumber then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.TRANSACTION.CONTROL_MISMATCH", "SE02 control " || v || " does not match ST02 control " || transaction~controlNumber, trailerControl, "X12_ENVELOPE"))
      end
    end
  end

  do group over document~groups
    if group~trailer == .nil then do
      report~addFinding(.X12ValidationFinding~new("ERROR", "X12.GROUP.GE.MISSING", "Functional group " || group~controlNumber || " has no GE trailer", group, "X12_ENVELOPE"))
      iterate
    end
    countElement = group~trailer~element(1)
    if countElement \== .nil then do
      v = countElement~scalarValue
      if v \== .nil then do
        if datatype(v, "W") then do
          if v \= group~transactions~items then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.GROUP.TRANSACTION_COUNT", "GE declares " || v || " transactions but group contains " || group~transactions~items, countElement, "X12_ENVELOPE"))
        end
        else report~addFinding(.X12ValidationFinding~new("ERROR", "X12.GROUP.TRANSACTION_COUNT.TYPE", "GE transaction count is not an integer: " || v, countElement, "X12_ENVELOPE"))
      end
    end
    controlElement = group~trailer~element(2)
    if controlElement \== .nil then do
      v=controlElement~scalarValue
      if v \== .nil then do
        if v \== group~controlNumber then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.GROUP.CONTROL_MISMATCH", "GE02 control " || v || " does not match GS06 control " || group~controlNumber, controlElement, "X12_ENVELOPE"))
      end
    end
  end

  do interchange over document~interchanges
    if interchange~trailer == .nil then do
      report~addFinding(.X12ValidationFinding~new("ERROR", "X12.INTERCHANGE.IEA.MISSING", "Interchange " || interchange~controlNumber || " has no IEA trailer", interchange, "X12_ENVELOPE"))
      iterate
    end
    countElement = interchange~trailer~element(1)
    if countElement \== .nil then do
      v=countElement~scalarValue
      if v \== .nil then do
        if datatype(v, "W") then do
          if v \= interchange~groups~items then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.INTERCHANGE.GROUP_COUNT", "IEA declares " || v || " groups but interchange contains " || interchange~groups~items, countElement, "X12_ENVELOPE"))
        end
        else report~addFinding(.X12ValidationFinding~new("ERROR", "X12.INTERCHANGE.GROUP_COUNT.TYPE", "IEA group count is not an integer: " || v, countElement, "X12_ENVELOPE"))
      end
    end
    controlElement = interchange~trailer~element(2)
    if controlElement \== .nil then do
      v=controlElement~scalarValue
      if v \== .nil then do
        if v \== interchange~controlNumber then report~addFinding(.X12ValidationFinding~new("ERROR", "X12.INTERCHANGE.CONTROL_MISMATCH", "IEA02 control " || v || " does not match ISA13 control " || interchange~controlNumber, controlElement, "X12_ENVELOPE"))
      end
    end
  end

  return report~complete


::requires "RichSourceCore.cls"

