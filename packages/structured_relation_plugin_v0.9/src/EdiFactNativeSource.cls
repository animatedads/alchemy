/*
 * EdiFactNativeSource v0.4
 *
 * ooRexx-native EDIFACT object model and selector engine.
 *
 * Design invariant: an interchange is retained as structured source objects.
 * Segments, elements and components preserve lexical form, decoded form,
 * source spans, hierarchy and envelope/message identity.  Relational values
 * are projections over these objects, never the native representation.
 */

::class EdiFactValidationFinding subclass RichSourceFinding public

::class EdiFactBusinessFact subclass RichBusinessFact public
::method provenance
  p = .table~new
  p["source"] = self~source
  p["row"] = self~row
  p["createdAt"] = self~createdAt
  sourceObject = self~source
  if sourceObject \== .nil then do
    p["sourceProvenance"] = sourceObject~provenance
    p["document"] = sourceObject~document
    if sourceObject~hasMethod("MESSAGE") then p["message"] = sourceObject~message
    if sourceObject~hasMethod("SEGMENT") then p["segment"] = sourceObject~segment
  end
  rowObject = self~row
  if rowObject \== .nil then do
    p["origin"] = rowObject~origin
    p["projection"] = rowObject~projection
  end
  return p


::class EdiFactSourceSpan public
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


::class EdiFactSourceAnnotation public
::attribute document get
::attribute kind get
::attribute lexicalValue get
::attribute span get
::attribute ordinal get

::method init
  expose document kind lexicalValue span ordinal
  use arg documentArg, kindArg, lexicalValueArg, spanArg, ordinalArg
  document = documentArg
  kind = kindArg~string~translate
  lexicalValue = lexicalValueArg
  span = spanArg
  ordinal = ordinalArg

::method line
  expose span
  return span~startLine

::method path
  expose ordinal
  return "/ANNOTATION[" || ordinal || "]"

::method provenance
  expose document kind lexicalValue span ordinal
  p = .table~new
  p["kind"] = "EDIFACT_SOURCE_ANNOTATION"
  p["annotationKind"] = kind
  p["document"] = document
  p["ordinal"] = ordinal
  p["path"] = self~path
  p["line"] = self~line
  p["span"] = span
  p["lexicalValue"] = lexicalValue
  return p

::method string
  expose kind ordinal
  return "EDIFACT-ANNOTATION(" || kind || "#" || ordinal || ")"

::class EdiFactSeparators public
::attribute component get
::attribute element get
::attribute decimal get
::attribute release get
::attribute repetition get
::attribute segment get
::attribute explicitUna get
::attribute unaLexical get

::method init
  expose component element decimal release repetition segment explicitUna unaLexical
  use arg componentArg = ":", elementArg = "+", decimalArg = ".", releaseArg = "?", repetitionArg = "*", segmentArg = "'", explicitUnaArg = .false, unaLexicalArg = ""
  component = componentArg
  element = elementArg
  decimal = decimalArg
  release = releaseArg
  repetition = repetitionArg
  segment = segmentArg
  explicitUna = explicitUnaArg
  unaLexical = unaLexicalArg

::method fromSource class
  use arg text
  if text~length >= 9 then do
    if text~substr(1, 3) = "UNA" then do
      return self~new(text~substr(4, 1), text~substr(5, 1), text~substr(6, 1), -
                      text~substr(7, 1), text~substr(8, 1), text~substr(9, 1), .true, text~substr(1, 9))
    end
  end
  return self~new

::method string
  expose component element decimal release repetition segment
  return "EDIFACT-SEPARATORS(" || component || element || decimal || release || repetition || segment || ")"


::class EdiFactComponent public
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

::method message
  expose repetition
  return repetition~message

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
  p["kind"] = "EDIFACT_COMPONENT"
  p["document"] = self~document
  p["message"] = self~message
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


::class EdiFactRepetition public
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
  component = .EdiFactComponent~new(self, components~items + 1, lexicalValue, value, span)
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

::method message
  expose element
  return element~message

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
  p["kind"] = "EDIFACT_REPETITION"
  p["document"] = self~document
  p["message"] = self~message
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
  return "EDIFACT-REPETITION(R" || position || ",components=" || components~items || ")"


::class EdiFactElement public
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
  repetition = .EdiFactRepetition~new(self, repetitions~items + 1, lexicalValue, span)
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

::method message
  expose segment
  return segment~message

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
  p["kind"] = "EDIFACT_ELEMENT"
  p["document"] = self~document
  p["message"] = self~message
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
  return "EDIFACT-ELEMENT(E" || position || ",repetitions=" || repetitions~items || ")"


::class EdiFactSegment public
::attribute document get
::attribute tag get
::attribute lexicalValue get
::attribute span get
::attribute ordinal get
::attribute elements get
::attribute message
::attribute group
::attribute interchange

::method init
  expose document tag lexicalValue span ordinal elements message group interchange
  use arg documentArg, tagArg, lexicalValueArg, spanArg, ordinalArg
  document = documentArg
  tag = tagArg~string~translate
  lexicalValue = lexicalValueArg
  span = spanArg
  ordinal = ordinalArg
  elements = .array~new
  message = .nil
  group = .nil
  interchange = .nil

::method addElement
  expose elements
  use arg lexicalValue, span
  element = .EdiFactElement~new(self, elements~items + 1, lexicalValue, span)
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

::method messageOccurrence
  expose message tag
  if message == .nil then return self~occurrence
  count = 0
  do segment over message~segments
    if segment~tag = tag then count = count + 1
    if segment == self then return count
  end
  return count

::method path
  expose tag message group interchange
  suffix = tag || "[" || self~messageOccurrence || "]"
  if message \== .nil then return message~path || "/" || suffix
  if group \== .nil then return group~path || "/" || suffix
  if interchange \== .nil then return interchange~path || "/" || suffix
  return "/" || suffix

::method provenance
  expose document tag lexicalValue span ordinal elements message group interchange
  p = .table~new
  p["kind"] = "EDIFACT_SEGMENT"
  p["document"] = document
  p["message"] = message
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
  return "EDIFACT-SEGMENT(" || tag || "#" || ordinal || ")"


::class EdiFactMessage public
::attribute document get
::attribute interchange
::attribute group
::attribute ordinal get
::attribute segments get
::attribute header
::attribute trailer
::attribute reference get
::attribute messageType get
::attribute version get
::attribute release get
::attribute agency get
::attribute associationCode get
::attribute span

::method init
  expose document interchange group ordinal segments header trailer reference messageType version release agency associationCode span
  use arg documentArg, ordinalArg
  document = documentArg
  ordinal = ordinalArg
  interchange = .nil
  group = .nil
  segments = .array~new
  header = .nil
  trailer = .nil
  reference = ""
  messageType = ""
  version = ""
  release = ""
  agency = ""
  associationCode = ""
  span = .nil

::method addSegment
  expose segments header trailer reference messageType version release agency associationCode
  use arg segment
  segments~append(segment)
  segment~message = self
  if segment~tag = "UNH" then do
    header = segment
    refElement = segment~element(1)
    if refElement \== .nil then do
      refValue = refElement~scalarValue
      if refValue \== .nil then reference = refValue
    end
    typeElement = segment~element(2)
    if typeElement \== .nil then do
      c = typeElement~component(1); if c \== .nil then messageType = c~value~translate
      c = typeElement~component(2); if c \== .nil then version = c~value~translate
      c = typeElement~component(3); if c \== .nil then release = c~value~translate
      c = typeElement~component(4); if c \== .nil then agency = c~value~translate
      c = typeElement~component(5); if c \== .nil then associationCode = c~value
    end
  end
  if segment~tag = "UNT" then trailer = segment
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
  return header~element(1)

::method sourceForType
  expose header
  if header == .nil then return .nil
  e = header~element(2)
  if e == .nil then return .nil
  return e~component(1)

::method sourceForVersion
  expose header
  if header == .nil then return .nil
  e = header~element(2)
  if e == .nil then return .nil
  return e~component(2)

::method sourceForRelease
  expose header
  if header == .nil then return .nil
  e = header~element(2)
  if e == .nil then return .nil
  return e~component(3)

::method sourceForAgency
  expose header
  if header == .nil then return .nil
  e = header~element(2)
  if e == .nil then return .nil
  return e~component(4)

::method line
  expose header
  if header == .nil then return 0
  return header~line

::method path
  expose interchange group ordinal
  if group \== .nil then return group~path || "/MESSAGE[" || ordinal || "]"
  if interchange \== .nil then return interchange~path || "/MESSAGE[" || ordinal || "]"
  return "/MESSAGE[" || ordinal || "]"

::method provenance
  expose document interchange group ordinal segments header trailer reference messageType version release agency associationCode
  p = .table~new
  p["kind"] = "EDIFACT_MESSAGE"
  p["document"] = document
  p["interchange"] = interchange
  p["group"] = group
  p["ordinal"] = ordinal
  p["path"] = self~path
  p["reference"] = reference
  p["messageType"] = messageType
  p["version"] = version
  p["release"] = release
  p["agency"] = agency
  p["associationCode"] = associationCode
  p["segments"] = segments
  return p

::method string
  expose reference messageType
  return "EDIFACT-MESSAGE(" || messageType || "," || reference || ")"


::class EdiFactFunctionalGroup public
::attribute document get
::attribute interchange
::attribute ordinal get
::attribute segments get
::attribute messages get
::attribute header
::attribute trailer
::attribute reference get
::attribute functionalId get

::method init
  expose document interchange ordinal segments messages header trailer reference functionalId
  use arg documentArg, ordinalArg
  document = documentArg
  ordinal = ordinalArg
  interchange = .nil
  segments = .array~new
  messages = .array~new
  groups = .array~new
  header = .nil
  trailer = .nil
  reference = ""
  functionalId = ""

::method addSegment
  expose segments header trailer reference functionalId
  use arg segment
  segments~append(segment)
  segment~group = self
  if segment~tag = "UNG" then do
    header = segment
    e = segment~element(1)
    if e \== .nil then do
      v = e~scalarValue
      if v \== .nil then functionalId = v
    end
    e = segment~element(5)
    if e \== .nil then do
      v = e~scalarValue
      if v \== .nil then reference = v
    end
  end
  if segment~tag = "UNE" then trailer = segment
  return segment

::method addMessage
  expose messages
  use arg message
  messages~append(message)
  message~group = self
  return message

::method path
  expose interchange ordinal
  if interchange \== .nil then return interchange~path || "/GROUP[" || ordinal || "]"
  return "/GROUP[" || ordinal || "]"

::method provenance
  expose document interchange ordinal segments messages header trailer reference functionalId
  p = .table~new
  p["kind"] = "EDIFACT_FUNCTIONAL_GROUP"
  p["document"] = document
  p["interchange"] = interchange
  p["ordinal"] = ordinal
  p["path"] = self~path
  p["reference"] = reference
  p["functionalId"] = functionalId
  p["segments"] = segments
  p["messages"] = messages
  return p

::method string
  expose reference functionalId
  return "EDIFACT-GROUP(" || functionalId || "," || reference || ")"

::class EdiFactInterchange public
::attribute document get
::attribute ordinal get
::attribute segments get
::attribute messages get
::attribute groups get
::attribute header
::attribute trailer
::attribute controlReference get

::method init
  expose document ordinal segments messages groups header trailer controlReference
  use arg documentArg, ordinalArg
  document = documentArg
  ordinal = ordinalArg
  segments = .array~new
  messages = .array~new
  groups = .array~new
  header = .nil
  trailer = .nil
  controlReference = ""

::method addSegment
  expose segments header trailer controlReference
  use arg segment
  segments~append(segment)
  segment~interchange = self
  if segment~tag = "UNB" then do
    header = segment
    e = segment~element(5)
    if e \== .nil then do
      v = e~scalarValue
      if v \== .nil then controlReference = v
    end
  end
  if segment~tag = "UNZ" then trailer = segment
  return segment

::method addGroup
  expose groups
  use arg group
  groups~append(group)
  group~interchange = self
  return group

::method addMessage
  expose messages
  use arg message
  messages~append(message)
  message~interchange = self
  return message

::method path
  expose ordinal
  return "/INTERCHANGE[" || ordinal || "]"

::method provenance
  expose document ordinal segments messages groups header trailer controlReference
  p = .table~new
  p["kind"] = "EDIFACT_INTERCHANGE"
  p["document"] = document
  p["ordinal"] = ordinal
  p["path"] = self~path
  p["controlReference"] = controlReference
  p["segments"] = segments
  p["messages"] = messages
  p["groups"] = groups
  return p

::method string
  expose ordinal controlReference
  return "EDIFACT-INTERCHANGE(" || ordinal || "," || controlReference || ")"


::class EdiFactSelection public
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
  p["kind"] = "EDIFACT_SELECTION"
  p["document"] = document
  p["expression"] = expression
  p["context"] = context
  p["selectionKind"] = kind
  p["nodes"] = nodes
  p["createdAt"] = createdAt
  return p

::method string
  expose kind nodes value
  if kind = "NODESET" then return "EDIFACT-NODESET(" || nodes~items || ")"
  if value == .nil then return "EDIFACT-SCALAR(NIL)"
  return "EDIFACT-SCALAR"


::class EdiFactValidationReport public
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
  return "EDIFACT-VALIDATION(" || name || "," || status || ",findings=" || findings~items || ")"


::class EdiFactDocumentContext public
::attribute source get
::attribute sourceText get
::attribute separators get
::attribute segments get
::attribute interchanges get
::attribute messages get
::attribute groups get
::attribute annotations get
::attribute history get
::attribute validationFindings get
::attribute validationReports get
::attribute metadata get
::attribute openedAt get
::attribute parserName get
::attribute closed get
::attribute lineStarts get

::method init
  expose source sourceText separators segments interchanges messages groups annotations history validationFindings validationReports metadata openedAt parserName closed lineStarts
  use arg sourceArg, textArg = .nil
  source = sourceArg~string
  sourceText = textArg
  if sourceText == .nil then sourceText = self~readSource(source)
  separators = .EdiFactSeparators~fromSource(sourceText)
  segments = .array~new
  interchanges = .array~new
  messages = .array~new
  groups = .array~new
  annotations = .array~new
  history = .array~new
  validationFindings = .array~new
  validationReports = .array~new
  metadata = .table~new
  openedAt = .DateTime~new~utcIsoDate
  parserName = "OOREXX_NATIVE_EDIFACT_V0.4"
  closed = .false
  lineStarts = self~buildLineStarts(sourceText)
  parser = .EdiFactNativeParser~new(self, sourceText, separators)
  parser~parse
  history~append(.RichProcessingEvent~new("PARSE", "OOREXX_NATIVE_EDIFACT", source, self))

::method fromText class
  use arg text, source = "memory:edifact"
  return self~new(source, text)

::method readSource private
  use arg sourcePath
  s = .stream~new(sourcePath)
  openStatus = s~open("READ")
  if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Unable to open EDIFACT source:" sourcePath || " status=" || openStatus)
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
  return .EdiFactSourceSpan~new(source, startOffset, endOffset, startLC[1], startLC[2], endLC[1], endLC[2])

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

::method addMessage
  expose messages
  use arg message
  messages~append(message)
  return message

::method addGroup
  expose groups
  use arg group
  groups~append(group)
  return group

::method addAnnotation
  expose annotations
  use arg annotation
  annotations~append(annotation)
  return annotation

::method select
  expose history
  use arg expression, context = .nil
  selection = .EdiFactSelectorEngine~evaluate(self, expression~string, context)
  history~append(.RichProcessingEvent~new("SELECT", "EDIFACT_SELECTOR", expression~string, selection))
  return selection

::method addFinding
  expose validationFindings
  use arg finding
  validationFindings~append(finding)
  return finding

::method validateEnvelope
  expose validationReports history
  report = .EdiFactEnvelopeValidator~validate(self)
  validationReports~append(report)
  history~append(.RichProcessingEvent~new("VALIDATE", "EDIFACT_ENVELOPE", report~status, report))
  return report

::method close
  expose closed history source
  if closed then return .true
  closed = .true
  history~append(.RichProcessingEvent~new("LIFECYCLE", "CLOSE", source, self))
  return .true

::method string
  expose source parserName
  return "EDIFACT-DOCUMENT(" || parserName || "," || source || ")"


::class EdiFactNativeParser public
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
  startOffset = 1
  if separators~explicitUna then do
    unaSpan = document~span(1, 9)
    unaSegment = .EdiFactSegment~new(document, "UNA", separators~unaLexical, unaSpan, 1)
    document~addSegment(unaSegment)
    startOffset = 10
  end

  currentInterchange = .nil
  currentGroup = .nil
  currentMessage = .nil
  position = startOffset
  do while position <= text~length
    do while position <= text~length
      ch = text~substr(position, 1)
      if ch = " " | ch = "09"x | ch = "0d"x | ch = "0a"x then do
        position = position + 1
        iterate
      end
      if ch = "/" then do
        if position < text~length then do
          if text~substr(position, 2) = "/*" then do
            commentStart = position
            closeRel = text~substr(position + 2)~pos("*/")
            if closeRel = 0 then raise syntax 93.900 additional("Unterminated EDIFACT source annotation at offset" commentStart)
            commentEnd = position + closeRel + 3
            lexical = text~substr(commentStart, commentEnd - commentStart + 1)
            annotation = .EdiFactSourceAnnotation~new(document, "BLOCK_COMMENT", lexical, document~span(commentStart, commentEnd), document~annotations~items + 1)
            document~addAnnotation(annotation)
            position = commentEnd + 1
            iterate
          end
        end
      end
      leave
    end
    if position > text~length then leave

    segmentStart = position
    released = .false
    segmentEnd = 0
    do while position <= text~length
      ch = text~substr(position, 1)
      if released then do
        released = .false
        position = position + 1
        iterate
      end
      if ch = separators~release then do
        released = .true
        position = position + 1
        iterate
      end
      if ch = separators~segment then do
        segmentEnd = position
        leave
      end
      position = position + 1
    end
    if segmentEnd = 0 then segmentEnd = text~length + 1

    rawEnd = segmentEnd - 1
    if rawEnd < segmentStart then raw = ""
    else raw = text~substr(segmentStart, rawEnd - segmentStart + 1)
    if raw <> "" then do
      segment = self~parseSegment(raw, segmentStart, segmentEnd)
      document~addSegment(segment)

      if segment~tag = "UNB" then do
        currentInterchange = .EdiFactInterchange~new(document, document~interchanges~items + 1)
        document~addInterchange(currentInterchange)
        currentInterchange~addSegment(segment)
      end
      else do
        if currentInterchange \== .nil then currentInterchange~addSegment(segment)
      end

      if segment~tag = "UNG" then do
        currentGroup = .EdiFactFunctionalGroup~new(document, document~groups~items + 1)
        document~addGroup(currentGroup)
        if currentInterchange \== .nil then currentInterchange~addGroup(currentGroup)
        currentGroup~addSegment(segment)
      end
      else if currentGroup \== .nil then currentGroup~addSegment(segment)

      if segment~tag = "UNH" then do
        currentMessage = .EdiFactMessage~new(document, document~messages~items + 1)
        document~addMessage(currentMessage)
        if currentInterchange \== .nil then currentInterchange~addMessage(currentMessage)
        if currentGroup \== .nil then currentGroup~addMessage(currentMessage)
        currentMessage~addSegment(segment)
      end
      else if currentMessage \== .nil then do
        currentMessage~addSegment(segment)
      end

      if segment~tag = "UNT" then currentMessage = .nil
      if segment~tag = "UNE" then currentGroup = .nil
      if segment~tag = "UNZ" then currentInterchange = .nil
    end

    if segmentEnd > text~length then leave
    position = segmentEnd + 1
  end
  return document

::method parseSegment private
  expose document separators
  use arg raw, absoluteStart, terminatorOffset
  tokens = self~splitPreserve(raw, separators~element, absoluteStart)
  if tokens~items = 0 then raise syntax 93.900 additional("Empty EDIFACT segment")
  tagToken = tokens[1]
  tag = tagToken["text"]~strip~translate
  segmentSpan = document~span(absoluteStart, terminatorOffset)
  segment = .EdiFactSegment~new(document, tag, raw || separators~segment, segmentSpan, document~segments~items + 1)

  do tokenIndex = 2 to tokens~items
    token = tokens[tokenIndex]
    elementSpan = document~span(token["start"], token["end"])
    element = segment~addElement(token["text"], elementSpan)
    if separators~repetition = " " then repetitions = self~singleToken(token["text"], token["start"])
    else repetitions = self~splitPreserve(token["text"], separators~repetition, token["start"])
    do repetitionToken over repetitions
      repetitionSpan = document~span(repetitionToken["start"], repetitionToken["end"])
      repetition = element~addRepetition(repetitionToken["text"], repetitionSpan)
      components = self~splitPreserve(repetitionToken["text"], separators~component, repetitionToken["start"])
      do componentToken over components
        decoded = self~decodeReleased(componentToken["text"])
        componentSpan = document~span(componentToken["start"], componentToken["end"])
        repetition~addComponent(componentToken["text"], decoded, componentSpan)
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
  expose separators
  use arg sourceText, separator, absoluteStart
  tokens = .array~new
  tokenStart = 1
  position = 1
  released = .false
  do while position <= sourceText~length
    ch = sourceText~substr(position, 1)
    if released then do
      released = .false
      position = position + 1
      iterate
    end
    if ch = separators~release then do
      released = .true
      position = position + 1
      iterate
    end
    if ch = separator then do
      tokenText = sourceText~substr(tokenStart, position - tokenStart)
      token = .table~new
      token["text"] = tokenText
      token["start"] = absoluteStart + tokenStart - 1
      token["end"] = absoluteStart + position - 2
      if token["end"] < token["start"] then token["end"] = token["start"]
      tokens~append(token)
      tokenStart = position + 1
    end
    position = position + 1
  end
  tokenText = sourceText~substr(tokenStart)
  token = .table~new
  token["text"] = tokenText
  token["start"] = absoluteStart + tokenStart - 1
  token["end"] = absoluteStart + sourceText~length - 1
  if token["end"] < token["start"] then token["end"] = token["start"]
  tokens~append(token)
  return tokens

::method decodeReleased private
  expose separators
  use arg lexical
  decoded = ""
  position = 1
  do while position <= lexical~length
    ch = lexical~substr(position, 1)
    if ch = separators~release then do
      if position < lexical~length then do
        decoded = decoded || lexical~substr(position + 1, 1)
        position = position + 2
        iterate
      end
    end
    decoded = decoded || ch
    position = position + 1
  end
  return decoded


::class EdiFactSelectorEngine public

::method evaluate class
  use arg document, expression, context = .nil
  expr = expression~strip
  if expr = "" then return .EdiFactSelection~new(document, expr, context)

  if context == .nil then do
    if expr~left(8)~caselessEquals("MESSAGE:") then do
      wantedType = expr~substr(9)~strip~translate
      selected = .array~new
      do message over document~messages
        if message~messageType = wantedType then selected~append(message)
      end
      return .EdiFactSelection~new(document, expr, document, selected)
    end
    if expr~caselessEquals("MESSAGE") then return .EdiFactSelection~new(document, expr, document, document~messages~copy)
    if expr~left(8)~caselessEquals("SEGMENT:") then do
      wantedTag = expr~substr(9)~strip~translate
      selected = .array~new
      do segment over document~segments
        if segment~tag = wantedTag then selected~append(segment)
      end
      return .EdiFactSelection~new(document, expr, document, selected)
    end
    raise syntax 93.900 additional("Unsupported EDIFACT document selector:" expr)
  end

  if context~isA(.EdiFactMessage) then return self~fromMessage(document, expr, context)
  if context~isA(.EdiFactSegment) then return self~fromSegment(document, expr, context)
  if context~isA(.EdiFactElement) then return self~fromElement(document, expr, context)
  raise syntax 93.900 additional("Unsupported EDIFACT selector context for:" expr)

::method fromMessage class private
  use arg document, expr, message
  if expr~left(1) = "@" then do
    attr = expr~substr(2)~translate
    selected = .array~new
    select
      when attr = "REFERENCE" then source = message~sourceForReference
      when attr = "TYPE" then source = message~sourceForType
      when attr = "VERSION" then source = message~sourceForVersion
      when attr = "RELEASE" then source = message~sourceForRelease
      when attr = "AGENCY" then source = message~sourceForAgency
      when attr = "GROUPREFERENCE" then do
        if message~group == .nil then return .EdiFactSelection~new(document, expr, message)
        return .EdiFactSelection~new(document, expr, message, .nil, "SCALAR", message~group~reference)
      end
      otherwise raise syntax 93.900 additional("Unsupported EDIFACT message attribute selector:" expr)
    end
    if source \== .nil then selected~append(source)
    return .EdiFactSelection~new(document, expr, message, selected)
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
  selectedSegments = message~segmentSelection(parsed["tag"], parsed["occurrence"], parsed["qualifier"])
  if remainder = "" then return .EdiFactSelection~new(document, expr, message, selectedSegments)
  return self~descendSegments(document, expr, message, selectedSegments, remainder)

::method fromSegment class private
  use arg document, expr, segment
  if expr~left(1) = "@" then do
    attr = expr~substr(2)~translate
    select
      when attr = "TAG" then source = segment
      when attr = "ORDINAL" then return .EdiFactSelection~new(document, expr, segment, .nil, "SCALAR", segment~ordinal)
      when attr = "MESSAGEREFERENCE" then do
        if segment~message == .nil then return .EdiFactSelection~new(document, expr, segment)
        selected = .array~new
        source = segment~message~sourceForReference
        if source \== .nil then selected~append(source)
        return .EdiFactSelection~new(document, expr, segment, selected)
      end
      when attr = "GROUPREFERENCE" then do
        if segment~group == .nil then return .EdiFactSelection~new(document, expr, segment)
        return .EdiFactSelection~new(document, expr, segment, .nil, "SCALAR", segment~group~reference)
      end
      when attr = "MESSAGETYPE" then do
        if segment~message == .nil then return .EdiFactSelection~new(document, expr, segment)
        selected = .array~new
        source = segment~message~sourceForType
        if source \== .nil then selected~append(source)
        return .EdiFactSelection~new(document, expr, segment, selected)
      end
      otherwise raise syntax 93.900 additional("Unsupported EDIFACT segment attribute selector:" expr)
    end
    return .EdiFactSelection~new(document, expr, segment, .nil, "SCALAR", source~tag)
  end

  parts = self~numericPath(expr)
  element = segment~element(parts["element"])
  selected = .array~new
  if element == .nil then return .EdiFactSelection~new(document, expr, segment, selected)
  if parts["explicitRepetition"] then do
    repetition = element~repetition(parts["repetition"])
    if repetition == .nil then return .EdiFactSelection~new(document, expr, segment, selected)
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
  return .EdiFactSelection~new(document, expr, segment, selected)

::method fromElement class private
  use arg document, expr, element
  if \datatype(expr, "W") then raise syntax 93.900 additional("EDIFACT element selector must be component position:" expr)
  selected = .array~new
  component = element~component(expr)
  if component \== .nil then selected~append(component)
  return .EdiFactSelection~new(document, expr, element, selected)

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
  return .EdiFactSelection~new(document, expr, context, selected)

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
    if \datatype(second, "W") then raise syntax 93.900 additional("EDIFACT selector expected component position:" second)
    parsed["component"] = second
  end

  openBrace = first~pos("{")
  if openBrace = 0 then elementText = first
  else do
    closeBrace = first~lastPos("}")
    if closeBrace <= openBrace then raise syntax 93.900 additional("Malformed EDIFACT repetition selector:" first)
    elementText = first~substr(1, openBrace - 1)
    repetitionText = first~substr(openBrace + 1, closeBrace - openBrace - 1)
    if \datatype(repetitionText, "W") then raise syntax 93.900 additional("EDIFACT repetition must be numeric:" repetitionText)
    parsed["repetition"] = repetitionText
    parsed["explicitRepetition"] = .true
  end
  if \datatype(elementText, "W") then raise syntax 93.900 additional("EDIFACT selector expected element position:" elementText)
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
  if closeBracket <= openBracket then raise syntax 93.900 additional("Malformed EDIFACT segment selector:" spec)
  parsed["tag"] = spec~substr(1, openBracket - 1)~translate
  predicate = spec~substr(openBracket + 1, closeBracket - openBracket - 1)
  if predicate~left(1) = "=" then parsed["qualifier"] = predicate~substr(2)
  else do
    if \datatype(predicate, "W") then raise syntax 93.900 additional("EDIFACT segment occurrence must be numeric:" predicate)
    parsed["occurrence"] = predicate
  end
  return parsed


::class EdiFactEnvelopeValidator public

::method validate class
  use arg document
  report = .EdiFactValidationReport~new("EDIFACT_ENVELOPE", document)

  do message over document~messages
    if message~header == .nil then do
      report~addFinding(.EdiFactValidationFinding~new("ERROR", "EDIFACT.MESSAGE.UNH.MISSING", -
        "Message has no UNH header", message, "EDIFACT_ENVELOPE"))
    end
    if message~trailer == .nil then do
      report~addFinding(.EdiFactValidationFinding~new("ERROR", "EDIFACT.MESSAGE.UNT.MISSING", -
        "Message " || message~reference || " has no UNT trailer", message, "EDIFACT_ENVELOPE"))
      iterate
    end

    countElement = message~trailer~element(1)
    if countElement \== .nil then do
      expectedText = countElement~scalarValue
      if expectedText \== .nil then do
        if datatype(expectedText, "W") then do
          actualCount = message~segments~items
          if expectedText \= actualCount then report~addFinding(.EdiFactValidationFinding~new("ERROR", -
            "EDIFACT.MESSAGE.SEGMENT_COUNT", "UNT declares " || expectedText || " segments but message contains " || actualCount, -
            countElement, "EDIFACT_ENVELOPE"))
        end
        else report~addFinding(.EdiFactValidationFinding~new("ERROR", "EDIFACT.MESSAGE.SEGMENT_COUNT.TYPE", -
          "UNT segment count is not an integer: " || expectedText, countElement, "EDIFACT_ENVELOPE"))
      end
    end

    trailerRef = message~trailer~element(2)
    if trailerRef \== .nil then do
      trailerRefValue = trailerRef~scalarValue
      if trailerRefValue \== .nil then do
        if trailerRefValue \== message~reference then report~addFinding(.EdiFactValidationFinding~new("ERROR", -
          "EDIFACT.MESSAGE.REFERENCE_MISMATCH", "UNT reference " || trailerRefValue || " does not match UNH reference " || message~reference, -
          trailerRef, "EDIFACT_ENVELOPE"))
      end
    end
  end

  do group over document~groups
    if group~trailer == .nil then do
      report~addFinding(.EdiFactValidationFinding~new("ERROR", "EDIFACT.GROUP.UNE.MISSING", -
        "Functional group " || group~reference || " has no UNE trailer", group, "EDIFACT_ENVELOPE"))
      iterate
    end
    countElement = group~trailer~element(1)
    if countElement \== .nil then do
      expectedText = countElement~scalarValue
      if expectedText \== .nil then do
        if datatype(expectedText, "W") then do
          actualCount = group~messages~items
          if expectedText \= actualCount then report~addFinding(.EdiFactValidationFinding~new("ERROR", -
            "EDIFACT.GROUP.MESSAGE_COUNT", "UNE declares " || expectedText || " messages but group contains " || actualCount, -
            countElement, "EDIFACT_ENVELOPE"))
        end
      end
    end
    trailerRef = group~trailer~element(2)
    if trailerRef \== .nil then do
      trailerValue = trailerRef~scalarValue
      if trailerValue \== .nil then do
        if group~reference <> "" then do
          if trailerValue \== group~reference then report~addFinding(.EdiFactValidationFinding~new("ERROR", -
            "EDIFACT.GROUP.REFERENCE_MISMATCH", "UNE reference " || trailerValue || " does not match UNG reference " || group~reference, -
            trailerRef, "EDIFACT_ENVELOPE"))
        end
      end
    end
  end

  do interchange over document~interchanges
    if interchange~trailer == .nil then do
      report~addFinding(.EdiFactValidationFinding~new("ERROR", "EDIFACT.INTERCHANGE.UNZ.MISSING", -
        "Interchange " || interchange~controlReference || " has no UNZ trailer", interchange, "EDIFACT_ENVELOPE"))
      iterate
    end

    messageCountElement = interchange~trailer~element(1)
    if messageCountElement \== .nil then do
      expectedText = messageCountElement~scalarValue
      if expectedText \== .nil then do
        if datatype(expectedText, "W") then do
          if interchange~groups~items > 0 then actualCount = interchange~groups~items
          else actualCount = interchange~messages~items
          if expectedText \= actualCount then report~addFinding(.EdiFactValidationFinding~new("ERROR", -
            "EDIFACT.INTERCHANGE.MESSAGE_COUNT", "UNZ declares " || expectedText || " messages but interchange contains " || actualCount, -
            messageCountElement, "EDIFACT_ENVELOPE"))
        end
        else report~addFinding(.EdiFactValidationFinding~new("ERROR", "EDIFACT.INTERCHANGE.MESSAGE_COUNT.TYPE", -
          "UNZ message count is not an integer: " || expectedText, messageCountElement, "EDIFACT_ENVELOPE"))
      end
    end

    trailerRef = interchange~trailer~element(2)
    if trailerRef \== .nil then do
      trailerValue = trailerRef~scalarValue
      if trailerValue \== .nil then do
        if interchange~controlReference <> "" then do
          if trailerValue \== interchange~controlReference then report~addFinding(.EdiFactValidationFinding~new("ERROR", -
            "EDIFACT.INTERCHANGE.REFERENCE_MISMATCH", "UNZ reference " || trailerValue || " does not match UNB reference " || interchange~controlReference, -
            trailerRef, "EDIFACT_ENVELOPE"))
        end
      end
    end
  end

  return report~complete


::requires "RichSourceCore.cls"
