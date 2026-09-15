/******************************************************************************/
/* AlchemyReport.cls — sealed lineage-bearing report documents (v0.14)         */
/*                                                                            */
/* Invariants:                                                                */
/*   * GROUNDED claims require at least one PRIMARY or SUPPORTING binding     */
/*   * bindings name retained source points; they do not replace sources      */
/*   * assessments are not facts                                              */
/*   * seal computes a stable fingerprint of the machine form                 */
/*   * trails must terminate in a leaf source or UNRESOLVED                   */
/******************************************************************************/

::class AlchemyReport public
::method version class
  return "0.14"
::method capabilities class
  return .array~of("REPORT_DOCUMENT", "REPORT_TRAIL", "REPORT_FINGERPRINT",,
                   "REPORT_PROJECTION", "REPORT_TRANSFORM_REGISTRY",,
                   "REPORT_ADAPTER_OPTIONAL")


::class ReportFingerprint public
::method of class
  use arg text
  numeric digits 20
  t = text~string
  h = 2166136261
  do i = 1 to t~length
     h = (h * 16777619 + c2d(t~substr(i, 1))) // 4294967296
  end
  return "FINGERPRINT/1:" || d2x(h, 8) || ":" || t~length


::class ReportSealDigest public
/* Prefer accelerated .SHA512 from oorexx_crypto when that class is loaded.
   This file does not ::requires crypto.cls — operators pull it in.
   Fallback is FINGERPRINT/1 so the package still seals standalone. */
::method of class
  use arg text
  signal on syntax name fallback
  d = .SHA512~new(text~string)~digest
  if d~length = 128 then return "SHA-512:" || d~lower
fallback:
  return .ReportFingerprint~of(text)

::method engine class
  signal on syntax name none
  ignore = .SHA512~new("x")~digest
  return "SHA-512"
none:
  return "FINGERPRINT/1"


::class ReportBinding public
::attribute bindingId
::attribute role
::attribute sourceKind
::attribute sourcePoint
::attribute sourceDigest
::attribute span
::attribute asOf
::attribute transformId
::attribute privacyClass

::method init
  expose bindingId role sourceKind sourcePoint sourceDigest span asOf transformId privacyClass
  use arg bindingId, role, sourceKind, sourcePoint
  if arg(5, "E") then sourceDigest = arg(5); else sourceDigest = ""
  if arg(6, "E") then span = arg(6); else span = ""
  if arg(7, "E") then asOf = arg(7); else asOf = ""
  if arg(8, "E") then transformId = arg(8); else transformId = ""
  if arg(9, "E") then privacyClass = arg(9)~upper; else privacyClass = "UNKNOWN"
  role = role~upper
  sourceKind = sourceKind~upper
  bindingId = bindingId~string
  sourcePoint = sourcePoint~string
  self~validateRole
  self~validateKind

::method validateRole private
  expose role
  ok = .array~of("PRIMARY", "SUPPORTING", "CONTRADICTING", "DERIVED")
  do w over ok
     if role = w then return
  end
  raise syntax 40.900 array("bad binding role:" role)

::method validateKind private
  expose sourceKind
  /* Domain kinds are adapter vocabulary, not a core enum.
     Token: A-Z / 0-9 / underscore only. */
  if sourceKind = "" then
     raise syntax 40.900 array("empty sourceKind")
  do i = 1 to sourceKind~length
     ch = sourceKind~substr(i, 1)
     if datatype(ch, "A") then iterate
     if datatype(ch, "N") then iterate
     if ch = "_" then iterate
     raise syntax 40.900 array("bad sourceKind token:" sourceKind)
  end

::method isGrounding
  expose role
  return role = "PRIMARY" | role = "SUPPORTING"

::method machineLine
  expose bindingId role sourceKind sourcePoint sourceDigest span asOf transformId privacyClass
  return bindingId || "|" || role || "|" || sourceKind || "|" || sourcePoint,
      || "|" || sourceDigest || "|" || span || "|" || asOf,
      || "|" || transformId || "|" || privacyClass

::method point
  expose bindingId
  return "REPORT_BINDING:" || bindingId

::method string
  expose bindingId role sourceKind sourcePoint
  return "ReportBinding[" bindingId role sourceKind sourcePoint"]"


::class ReportClaim public
::attribute claimId
::attribute text
::attribute kind
::attribute status
::attribute bindingIds

::method init
  expose claimId text kind status bindingIds
  use arg claimId, text, kind
  if arg(4, "E") then status = arg(4)~upper; else status = "UNSOURCED"
  bindingIds = .array~new
  claimId = claimId~string
  text = text~string
  kind = kind~upper
  self~validateKind
  self~validateStatus

::method validateKind private
  expose kind
  ok = .array~of("FACT", "ASSESSMENT", "OBLIGATION", "METRIC", "NARRATIVE")
  do w over ok
     if kind = w then return
  end
  raise syntax 40.900 array("bad claim kind:" kind)

::method validateStatus private
  expose status
  ok = .array~of("GROUNDED", "PARTIAL", "UNSOURCED", "STALE")
  do w over ok
     if status = w then return
  end
  raise syntax 40.900 array("bad claim status:" status)

::method addBindingId
  expose bindingIds
  use arg id
  bindingIds~append(id~string)
  return self

::method point
  use arg reportId
  expose claimId
  return "REPORT:" || reportId || ":CLAIM:" || claimId

::method machineLine
  expose claimId text kind status bindingIds
  ids = ""
  do i = 1 to bindingIds~items
     ids = ids || bindingIds[i] || ","
  end
  return claimId || "|" || kind || "|" || status || "|" || ids || "|" || text

::method string
  expose claimId kind status
  return "ReportClaim[" claimId kind status"]"


::class ReportSection public
::attribute sectionId
::attribute title
::attribute claimIds

::method init
  expose sectionId title claimIds
  use arg sectionId, title
  sectionId = sectionId~string
  title = title~string
  claimIds = .array~new

::method addClaimId
  expose claimIds
  use arg id
  claimIds~append(id~string)
  return self

::method machineLine
  expose sectionId title claimIds
  ids = ""
  do i = 1 to claimIds~items
     ids = ids || claimIds[i] || ","
  end
  return sectionId || "|" || title || "|" || ids


::class ReportTrail public
::attribute claimId
::attribute steps
::attribute terminal

::method init
  expose claimId steps terminal
  use arg claimId
  claimId = claimId~string
  steps = .array~new
  terminal = "UNRESOLVED"

::method addStep
  expose steps
  use arg binding
  steps~append(binding)
  return self

::method closeAt
  expose terminal
  use arg term
  terminal = term~upper
  return self

::method isComplete
  expose terminal steps
  if steps~items = 0 then return .false
  return terminal \= "UNRESOLVED"

::method machineForm
  expose claimId steps terminal
  out = "TRAIL|" || claimId || "|" || terminal
  do i = 1 to steps~items
     out = out || .endOfLine || steps[i]~machineLine
  end
  return out

::method string
  expose claimId terminal steps
  return "ReportTrail[" claimId terminal "steps=" || steps~items || "]"


::class ReportDocument public
::attribute reportId
::attribute title
::attribute audience
::attribute claims
::attribute bindings
::attribute sections
::attribute sealed
::attribute sealedAt
::attribute digest
::attribute generation
::attribute transformRegistry
::attribute hidePrivacy

::method init
  expose reportId title audience claims bindings sections sealed sealedAt digest generation transformRegistry hidePrivacy
  use arg reportId, title
  reportId = reportId~string
  title = title~string
  if arg(3, "E") then audience = arg(3)~upper; else audience = "BOTH"
  claims = .directory~new
  bindings = .directory~new
  sections = .array~new
  sealed = .false
  sealedAt = ""
  digest = ""
  generation = 1
  transformRegistry = .nil
  hidePrivacy = .array~of("UNKNOWN")

::method hide
  expose hidePrivacy
  use arg className
  hidePrivacy~append(className~upper)
  return self

::method addBinding
  expose bindings sealed
  use arg binding
  if sealed then
     raise syntax 40.900 array("document is sealed")
  bindings[binding~bindingId] = binding
  return self

::method addClaim
  expose claims sealed
  use arg claim
  if sealed then
     raise syntax 40.900 array("document is sealed")
  claims[claim~claimId] = claim
  return self

::method addSection
  expose sections sealed
  use arg section
  if sealed then
     raise syntax 40.900 array("document is sealed")
  sections~append(section)
  return self

::method binding
  expose bindings
  use arg id
  return bindings[id]

::method claim
  expose claims
  use arg id
  return claims[id]

::method point
  expose reportId
  return "REPORT:" || reportId

::method requireUnsealed private
  expose sealed
  if sealed then
     raise syntax 40.900 array("document is sealed")

::method groundClaim
  /* Recompute status from bindings present on the document. */
  expose claims bindings
  use arg claimId
  c = claims[claimId]
  if c = .nil then
     raise syntax 40.900 array("unknown claim:" claimId)
  n = 0
  stale = 0
  do i = 1 to c~bindingIds~items
     b = bindings[c~bindingIds[i]]
     if b = .nil then iterate
     if b~isGrounding then n = n + 1
     if b~sourceDigest = "STALE" then stale = 1
  end
  if stale = 1 then c~status = "STALE"
  else if n = 0 then c~status = "UNSOURCED"
  else if n < c~bindingIds~items then c~status = "PARTIAL"
  else c~status = "GROUNDED"
  return c~status

::method groundAll
  expose claims
  s = .directory~new
  do id over claims
     s[id] = self~groundClaim(id)
  end
  return s

::method trail
  expose claims bindings
  use arg claimId
  c = claims[claimId]
  if c = .nil then
     raise syntax 40.900 array("unknown claim:" claimId)
  t = .ReportTrail~new(claimId)
  seen = .directory~new
  do i = 1 to c~bindingIds~items
     bid = c~bindingIds[i]
     if seen~hasIndex(bid) then
        raise syntax 40.900 array("circular or repeated binding on trail:" bid)
     seen[bid] = 1
     b = bindings[bid]
     if b = .nil then iterate
     t~addStep(b)
  end
  if t~steps~items = 0 then t~closeAt("UNRESOLVED")
  else t~closeAt("LEAF")
  return t

::method canSeal
  expose claims bindings
  /* FACT / OBLIGATION / METRIC must not remain UNSOURCED.
     GROUNDED claims must have a grounding binding that exists. */
  do id over claims
     c = claims[id]
     if c~status = "UNSOURCED" then do
        if c~kind = "FACT" | c~kind = "OBLIGATION" | c~kind = "METRIC" then
           return .false
     end
     if c~status = "GROUNDED" then do
        ok = 0
        do i = 1 to c~bindingIds~items
           b = bindings[c~bindingIds[i]]
           if b \= .nil, b~isGrounding then ok = 1
        end
        if ok = 0 then return .false
     end
  end
  return .true

::method machineForm
  expose reportId title audience claims bindings sections generation
  out = "REPORT|" || reportId || "|" || title || "|" || audience || "|" || generation
  keys = bindings~makeArray
  keys = self~sortedIds(keys)
  do i = 1 to keys~items
     out = out || .endOfLine || "B|" || bindings[keys[i]]~machineLine
  end
  keys = claims~makeArray
  keys = self~sortedIds(keys)
  do i = 1 to keys~items
     out = out || .endOfLine || "C|" || claims[keys[i]]~machineLine
  end
  do i = 1 to sections~items
     out = out || .endOfLine || "S|" || sections[i]~machineLine
  end
  return out

::method sortedIds private
  use arg arr
  /* insertion sort — small documents */
  n = arr~items
  do i = 2 to n
     v = arr[i]
     j = i - 1
     do while j >= 1
        if arr[j]~string <= v~string then leave
        arr[j + 1] = arr[j]
        j = j - 1
     end
     arr[j + 1] = v
  end
  return arr

::method seal
  expose sealed sealedAt digest generation bindings transformRegistry
  if transformRegistry \= .nil then do
     do id over bindings
        tid = bindings[id]~transformId
        if tid \= "" then ignore = transformRegistry~assertKnown(tid)
     end
  end
  self~groundAll
  if \self~canSeal then
     raise syntax 40.900 array("cannot seal: GROUNDED claim lacks grounding binding")
  digest = .ReportSealDigest~of(self~machineForm)
  sealedAt = time("L") date("S")
  sealed = .true
  return digest

::method humanForm
  expose reportId title claims bindings sections sealed digest
  out = title || "  [" || reportId || "]"
  if sealed then out = out || .endOfLine || "sealed " || digest
  do s = 1 to sections~items
     sec = sections[s]
     out = out || .endOfLine || .endOfLine || sec~title
     do i = 1 to sec~claimIds~items
        c = claims[sec~claimIds[i]]
        if c = .nil then iterate
        mark = self~statusMark(c~status)
        out = out || .endOfLine || "  " || mark || " " || c~text
        do j = 1 to c~bindingIds~items
           b = bindings[c~bindingIds[j]]
           if b = .nil then iterate
           out = out || .endOfLine || "      ↳ " || b~role || " " || b~sourceKind,
               || " " || b~sourcePoint
           if b~span \= "" then out = out || " @" || b~span
        end
     end
  end
  return out

::method statusMark private
  use arg st
  select
     when st = "GROUNDED" then return "●"
     when st = "PARTIAL" then return "◐"
     when st = "STALE" then return "△"
     otherwise return "○"
  end

::method string
  expose reportId sealed digest
  return "ReportDocument[" reportId "sealed=" || sealed digest"]"

::method points
  /* Stable drill targets for Wire / audit — not a second document. */
  expose reportId claims bindings sections
  out = .array~new
  out~append(self~point)
  keys = self~sortedIds(claims~makeArray)
  do i = 1 to keys~items
     out~append(claims[keys[i]]~point(reportId))
  end
  keys = self~sortedIds(bindings~makeArray)
  do i = 1 to keys~items
     out~append(bindings[keys[i]]~point)
  end
  do i = 1 to sections~items
     out~append("REPORT:" || reportId || ":SECTION:" || sections[i]~sectionId)
  end
  return out

::method machineTrace
  expose digest sealed
  lines = .array~new
  lines~append("TRACE|" || self~point || "|" || sealed || "|" || digest)
  pts = self~points
  do i = 1 to pts~items
     lines~append(pts[i])
  end
  acc = ""
  do i = 1 to lines~items
     if i = 1 then acc = lines[i]
     else acc = acc || .endOfLine || lines[i]
  end
  return acc

::method customerHumanForm
  /* Omits claims that rest on UNKNOWN privacy bindings. */
  expose reportId title claims bindings sections sealed digest
  out = title || "  [" || reportId || "]"
  if sealed then out = out || .endOfLine || "sealed " || digest
  do s = 1 to sections~items
     sec = sections[s]
     block = ""
     do i = 1 to sec~claimIds~items
        c = claims[sec~claimIds[i]]
        if c = .nil then iterate
        if self~claimTouchesHidden(c) then iterate
        mark = self~statusMark(c~status)
        block = block || .endOfLine || "  " || mark || " " || c~text
        do j = 1 to c~bindingIds~items
           b = bindings[c~bindingIds[j]]
           if b = .nil then iterate
           block = block || .endOfLine || "      ↳ " || b~role || " " || b~sourceKind,
               || " " || b~sourcePoint
        end
     end
     if block \= "" then
        out = out || .endOfLine || .endOfLine || sec~title || block
  end
  return out

::method claimTouchesUnknown
  use arg claim
  return self~claimTouchesHidden(claim)

::method claimTouchesHidden
  expose bindings hidePrivacy
  use arg claim
  do i = 1 to claim~bindingIds~items
     b = bindings[claim~bindingIds[i]]
     if b = .nil then iterate
     do j = 1 to hidePrivacy~items
        if b~privacyClass = hidePrivacy[j] then return .true
     end
  end
  return .false

::method markStaleIfDigestDiffers
  expose bindings sealed
  use arg bindingId, liveDigest
  if sealed then
     raise syntax 40.900 array("document is sealed")
  b = bindings[bindingId]
  if b = .nil then
     raise syntax 40.900 array("unknown binding:" bindingId)
  if b~sourceDigest \= "" & b~sourceDigest \= liveDigest then
     b~sourceDigest = "STALE"
  return b~sourceDigest


::class ReportTransformRegistry public
::method init
  expose names
  names = .directory~new
  /* v0.2 built-ins — operators register more */
  /* Domain transforms registered by adapter files, not by core. */

::method register
  expose names
  use arg transformId
  names[transformId~string] = 1
  return self

::method knows
  expose names
  use arg transformId
  if transformId = "" then return .true
  return names~hasIndex(transformId~string)

::method assertKnown
  use arg transformId
  if \self~knows(transformId) then
     raise syntax 40.900 array("unregistered transform:" transformId)
  return .true


::class ReportAggregate public
/* Fingerprint of an input-set so an average is still accusable. */
::attribute aggregateId
::attribute memberPoints
::attribute memberDigest

::method init
  expose aggregateId memberPoints memberDigest
  use arg aggregateId
  aggregateId = aggregateId~string
  memberPoints = .array~new
  memberDigest = ""

::method addMember
  expose memberPoints
  use arg point
  memberPoints~append(point~string)
  return self

::method sealMembers
  expose memberPoints memberDigest
  acc = ""
  n = memberPoints~items
  do i = 1 to n
     acc = acc || memberPoints[i] || .endOfLine
  end
  memberDigest = .ReportFingerprint~of(acc)
  return memberDigest

::method machineLine
  expose aggregateId memberDigest memberPoints
  return aggregateId || "|" || memberDigest || "|" || memberPoints~items


::class ReportCodec public
/* Split a machine line into n fields; remainder is the last field (claim text). */
::method split class
  use arg line, n
  parts = .array~new
  rest = line~string
  do i = 1 to n - 1
     p = rest~pos("|")
     if p = 0 then do
        parts~append(rest)
        rest = ""
        leave
     end
     parts~append(rest~left(p - 1))
     rest = rest~substr(p + 1)
  end
  parts~append(rest)
  return parts

::method load class
  use arg text
  lines = .array~new
  rest = text~string
  do while rest \= ""
     p = rest~pos(.endOfLine)
     if p = 0 then do
        lines~append(rest)
        leave
     end
     lines~append(rest~left(p - 1))
     rest = rest~substr(p + .endOfLine~length)
  end
  if lines~items = 0 then
     raise syntax 40.900 array("empty machine form")
  hdr = self~split(lines[1], 5)
  if hdr[1] \= "REPORT" then
     raise syntax 40.900 array("not a REPORT machine form")
  doc = .ReportDocument~new(hdr[2], hdr[3], hdr[4])
  if hdr~items >= 5, datatype(hdr[5], "W") then doc~generation = hdr[5]
  do i = 2 to lines~items
     line = lines[i]
     if line = "" then iterate
     tag = line~left(1)
     body = ""
     if line~length >= 3, line~substr(2, 1) = "|" then
        body = line~substr(3)
     else iterate
     select
        when tag = "B" then do
           f = self~split(body, 9)
           b = .ReportBinding~new(f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9])
           ignore = doc~addBinding(b)
        end
        when tag = "C" then do
           f = self~split(body, 5)
           c = .ReportClaim~new(f[1], f[5], f[2], f[3])
           ids = f[4]
           do while ids \= ""
              q = ids~pos(",")
              if q = 0 then do
                 if ids \= "" then ignore = c~addBindingId(ids)
                 leave
              end
              one = ids~left(q - 1)
              if one \= "" then ignore = c~addBindingId(one)
              ids = ids~substr(q + 1)
           end
           ignore = doc~addClaim(c)
        end
        when tag = "S" then do
           f = self~split(body, 3)
           sec = .ReportSection~new(f[1], f[2])
           ids = f[3]
           do while ids \= ""
              q = ids~pos(",")
              if q = 0 then do
                 if ids \= "" then ignore = sec~addClaimId(ids)
                 leave
              end
              one = ids~left(q - 1)
              if one \= "" then ignore = sec~addClaimId(one)
              ids = ids~substr(q + 1)
           end
           ignore = doc~addSection(sec)
        end
        otherwise nop
     end
  end
  return doc

