/* LdapBer.cls
 * Minimal definite-length BER codec for LDAP v0.1-dev9 wire qualification.
 * This is exact-binary protocol substrate, not directory policy.
 */

::class LdapBerBuild public
::constant API_VERSION "ldap.ber/0.1"

::class LdapBer public
::method byte class
  use strict arg n
  if n < 0 | n > 255 then raise syntax 88.900 array("BER byte out of range")
  return d2c(n)
::method encodeLength class
  use strict arg n
  if n < 0 then raise syntax 88.900 array("BER length must be non-negative")
  if n < 128 then return self~byte(n)
  bytes = ""
  v = n
  do while v > 0
    bytes = self~byte(v // 256) || bytes
    v = v % 256
  end
  return self~byte(128 + bytes~length) || bytes
::method decodeLength class
  use strict arg data, offset = 1
  out = .directory~new
  if offset > data~length then do
    out["ok"] = .false; out["code"] = "BER_TRUNCATED_LENGTH"; return out
  end
  first = c2d(data~substr(offset,1))
  if first < 128 then do
    out["ok"] = .true; out["length"] = first; out["next"] = offset + 1; return out
  end
  count = first - 128
  if count = 0 then do
    out["ok"] = .false; out["code"] = "BER_INDEFINITE_LENGTH_UNSUPPORTED"; return out
  end
  if count > 4 | offset + count > data~length then do
    out["ok"] = .false; out["code"] = "BER_BAD_LENGTH"; return out
  end
  n = 0
  i = 1
  do while i <= count
    n = n * 256 + c2d(data~substr(offset + i, 1))
    i += 1
  end
  out["ok"] = .true
  out["length"] = n
  out["next"] = offset + count + 1
  return out
::method tlv class
  use strict arg tag, value = ""
  return self~byte(tag) || self~encodeLength(value~length) || value
::method integer class
  use strict arg n
  if n < 0 then raise syntax 88.900 array("dev9 BER integer encoder expects non-negative integer")
  if n = 0 then body = '00'x
  else do
    body = ""
    v = n
    do while v > 0
      body = self~byte(v // 256) || body
      v = v % 256
    end
    if c2d(body~left(1)) >= 128 then body = '00'x || body
  end
  return self~tlv(2, body)
::method enumerated class
  use strict arg n
  encoded = self~integer(n)
  return self~byte(10) || encoded~substr(2)
::method boolean class
  use strict arg value
  if value then body = 'ff'x
  else body = '00'x
  return self~tlv(1, body)
::method octet class
  use strict arg value = ""
  return self~tlv(4, value~string)
::method sequence class
  use strict arg value = ""
  return self~tlv(48, value)
::method set class
  use strict arg value = ""
  return self~tlv(49, value)
::method readElement class
  use strict arg data, offset = 1
  out = .directory~new
  if offset > data~length then do
    out["ok"] = .false; out["code"] = "BER_EOF"; return out
  end
  tag = c2d(data~substr(offset,1))
  lenInfo = self~decodeLength(data, offset + 1)
  if \lenInfo["ok"] then return lenInfo
  valueStart = lenInfo["next"]
  n = lenInfo["length"]
  if valueStart + n - 1 > data~length then do
    out["ok"] = .false; out["code"] = "BER_TRUNCATED_VALUE"; return out
  end
  out["ok"] = .true
  out["tag"] = tag
  out["length"] = n
  if n = 0 then out["value"] = ""
  else out["value"] = data~substr(valueStart, n)
  out["next"] = valueStart + n
  return out
::method decodeUnsignedInteger class
  use strict arg bytes
  n = 0
  do i = 1 to bytes~length
    n = n * 256 + c2d(bytes~substr(i,1))
  end
  return n
::method hex class
  use strict arg bytes
  return c2x(bytes)~lower

::class LdapControl public
::attribute controlType get
::attribute criticality get
::attribute controlValue get
::attribute valuePresent get
::method init
  expose controlType criticality controlValue valuePresent
  use strict arg controlTypeArg, criticalityArg = .false, controlValueArg = .nil
  controlType = controlTypeArg~string
  criticality = criticalityArg
  valuePresent = controlValueArg <> .nil
  if valuePresent then controlValue = controlValueArg~string
  else controlValue = ""

::class LdapWireCodec public
::constant LDAP_VERSION 3
::constant OP_BIND_REQUEST 96
::constant OP_BIND_RESPONSE 97
::constant OP_UNBIND_REQUEST 66
::constant OP_SEARCH_REQUEST 99
::constant OP_SEARCH_ENTRY 100
::constant OP_SEARCH_DONE 101
::constant OP_MODIFY_REQUEST 102
::constant OP_MODIFY_RESPONSE 103
::constant OP_ADD_REQUEST 104
::constant OP_ADD_RESPONSE 105
::constant OP_DELETE_REQUEST 74
::constant OP_DELETE_RESPONSE 107
::constant OP_MODDN_REQUEST 108
::constant OP_MODDN_RESPONSE 109
::constant OP_COMPARE_REQUEST 110
::constant OP_COMPARE_RESPONSE 111
::constant OP_EXTENDED_REQUEST 119
::constant OP_EXTENDED_RESPONSE 120
::constant OP_INTERMEDIATE_RESPONSE 121

::method encodeControl class
  use strict arg control
  body = .LdapBer~octet(control~controlType)
  if control~criticality then body ||= .LdapBer~boolean(.true)
  if control~valuePresent then body ||= .LdapBer~octet(control~controlValue)
  return .LdapBer~sequence(body)
::method encodeControls class
  use strict arg controls = .nil
  if controls == .nil then return ""
  if controls~items = 0 then return ""
  body = ""
  do c over controls
    body ||= self~encodeControl(c)
  end
  /* LDAPMessage is defined with IMPLICIT TAGS; [0] replaces Controls' SEQUENCE tag. */
  return .LdapBer~tlv(160, body)
::method decodeControls class
  use strict arg value
  controls = .array~new
  pos = 1
  do while pos <= value~length
    c = .LdapBer~readElement(value, pos)
    if \c["ok"] | c["tag"] <> 48 then return self~failure("LDAP_CONTROL_INVALID")
    t = .LdapBer~readElement(c["value"], 1)
    if \t["ok"] | t["tag"] <> 4 then return self~failure("LDAP_CONTROL_TYPE_INVALID")
    cp = t["next"]
    critical = .false
    v = .nil
    if cp <= c["value"]~length then do
      e = .LdapBer~readElement(c["value"], cp)
      if \e["ok"] then return e
      if e["tag"] = 1 then do
        critical = e["value"] <> '00'x
        cp = e["next"]
        if cp <= c["value"]~length then do
          e = .LdapBer~readElement(c["value"], cp)
          if \e["ok"] then return e
          if e["tag"] <> 4 then return self~failure("LDAP_CONTROL_VALUE_INVALID")
          v = e["value"]
          cp = e["next"]
        end
      end
      else if e["tag"] = 4 then do
        v = e["value"]
        cp = e["next"]
      end
      else return self~failure("LDAP_CONTROL_FIELD_INVALID")
    end
    if cp <= c["value"]~length then return self~failure("LDAP_CONTROL_TRAILING_BYTES")
    controls~append(.LdapControl~new(t["value"], critical, v))
    pos = c["next"]
  end
  out = .directory~new; out["ok"] = .true; out["controls"] = controls; return out
::method findControl class
  use strict arg controls, controlType
  if controls == .nil then return .nil
  do c over controls
    if c~controlType = controlType then return c
  end
  return .nil
::method encodeMessage class
  use strict arg messageId, protocolOpBytes, controls = .nil
  return .LdapBer~sequence(.LdapBer~integer(messageId) || protocolOpBytes || self~encodeControls(controls))
::method decodeMessage class
  use strict arg bytes
  top = .LdapBer~readElement(bytes, 1)
  if \top["ok"] then return top
  if top["tag"] <> 48 then return self~failure("LDAP_MESSAGE_NOT_SEQUENCE")
  if top["next"] <> bytes~length + 1 then return self~failure("LDAP_MESSAGE_TRAILING_BYTES")
  body = top["value"]
  idEl = .LdapBer~readElement(body, 1)
  if \idEl["ok"] | idEl["tag"] <> 2 then return self~failure("LDAP_MESSAGE_ID_INVALID")
  opEl = .LdapBer~readElement(body, idEl["next"])
  if \opEl["ok"] then return opEl
  controls = .array~new
  if opEl["next"] <= body~length then do
    ce = .LdapBer~readElement(body, opEl["next"])
    if \ce["ok"] then return ce
    if ce["tag"] <> 160 then return self~failure("LDAP_MESSAGE_CONTROLS_INVALID")
    if ce["next"] <> body~length + 1 then return self~failure("LDAP_MESSAGE_TRAILING_FIELDS")
    decodedControls = self~decodeControls(ce["value"])
    if \decodedControls["ok"] then return decodedControls
    controls = decodedControls["controls"]
  end
  out = .directory~new
  out["ok"] = .true
  out["messageId"] = .LdapBer~decodeUnsignedInteger(idEl["value"])
  out["opTag"] = opEl["tag"]
  out["opValue"] = opEl["value"]
  out["controls"] = controls
  out["controlsPresent"] = controls~items > 0
  return out
::method failure class private
  use strict arg code
  d = .directory~new; d["ok"] = .false; d["code"] = code; return d
::method encodeResult class
  use strict arg appTag, messageId, resultCode, matchedDn = "", diagnostic = "", controls = .nil
  content = .LdapBer~enumerated(resultCode) || .LdapBer~octet(matchedDn) || .LdapBer~octet(diagnostic)
  return self~encodeMessage(messageId, .LdapBer~tlv(appTag, content), controls)
::method decodeResult class
  use strict arg opValue
  r = .directory~new
  codeEl = .LdapBer~readElement(opValue, 1)
  if \codeEl["ok"] | codeEl["tag"] <> 10 then return self~failure("LDAP_RESULT_CODE_INVALID")
  dnEl = .LdapBer~readElement(opValue, codeEl["next"])
  if \dnEl["ok"] | dnEl["tag"] <> 4 then return self~failure("LDAP_RESULT_DN_INVALID")
  diagEl = .LdapBer~readElement(opValue, dnEl["next"])
  if \diagEl["ok"] | diagEl["tag"] <> 4 then return self~failure("LDAP_RESULT_DIAGNOSTIC_INVALID")
  r["ok"] = .true
  r["resultCode"] = .LdapBer~decodeUnsignedInteger(codeEl["value"])
  r["matchedDn"] = dnEl["value"]
  r["diagnostic"] = diagEl["value"]
  return r
::method decodeBindRequest class
  use strict arg opValue
  v = .LdapBer~readElement(opValue, 1)
  if \v["ok"] | v["tag"] <> 2 then return self~failure("LDAP_BIND_VERSION_INVALID")
  name = .LdapBer~readElement(opValue, v["next"])
  if \name["ok"] | name["tag"] <> 4 then return self~failure("LDAP_BIND_NAME_INVALID")
  auth = .LdapBer~readElement(opValue, name["next"])
  if \auth["ok"] then return auth
  out = .directory~new
  out["ok"] = .true
  out["version"] = .LdapBer~decodeUnsignedInteger(v["value"])
  out["name"] = name["value"]
  if auth["tag"] = 128 then do
    out["authType"] = "SIMPLE"
    out["credential"] = auth["value"]
    return out
  end
  if auth["tag"] = 163 then do
    mech = .LdapBer~readElement(auth["value"], 1)
    if \mech["ok"] | mech["tag"] <> 4 then return self~failure("LDAP_SASL_MECHANISM_INVALID")
    credentials = .nil
    if mech["next"] <= auth["value"]~length then do
      ce = .LdapBer~readElement(auth["value"], mech["next"])
      if \ce["ok"] | ce["tag"] <> 4 then return self~failure("LDAP_SASL_CREDENTIALS_INVALID")
      credentials = ce["value"]
      if ce["next"] <= auth["value"]~length then return self~failure("LDAP_SASL_TRAILING_BYTES")
    end
    out["authType"] = "SASL"
    out["mechanism"] = mech["value"]
    out["credential"] = credentials
    return out
  end
  return self~failure("LDAP_BIND_AUTH_UNSUPPORTED")
::method encodeBindRequest class
  use strict arg messageId, bindName, credential
  content = .LdapBer~integer(self~LDAP_VERSION) || .LdapBer~octet(bindName) || .LdapBer~tlv(128, credential~string)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_BIND_REQUEST, content))
::method encodeSaslBindRequest class
  use strict arg messageId, mechanism, credentials = .nil, bindName = ""
  sasl = .LdapBer~octet(mechanism)
  if credentials <> .nil then sasl ||= .LdapBer~octet(credentials)
  content = .LdapBer~integer(self~LDAP_VERSION) || .LdapBer~octet(bindName) || .LdapBer~tlv(163, sasl)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_BIND_REQUEST, content))
::method filterEscape class
  use strict arg value
  return .LdapFilter~escapeAssertionValue(value)
::method decodeAvaFilter class private
  use strict arg element, operator
  a = .LdapBer~readElement(element["value"], 1)
  if \a["ok"] | a["tag"] <> 4 then return ""
  v = .LdapBer~readElement(element["value"], a["next"])
  if \v["ok"] | v["tag"] <> 4 then return ""
  if v["next"] <= element["value"]~length then return ""
  return "(" || a["value"] || operator || self~filterEscape(v["value"]) || ")"
::method decodeFilter class
  use strict arg element
  tag = element["tag"]
  select
    when tag = 135 then return "(" || element["value"] || "=*)"
    when tag = 163 then return self~decodeAvaFilter(element, "=")
    when tag = 165 then return self~decodeAvaFilter(element, ">=")
    when tag = 166 then return self~decodeAvaFilter(element, "<=")
    when tag = 168 then return self~decodeAvaFilter(element, "~=")
    when tag = 164 then do
      a = .LdapBer~readElement(element["value"], 1)
      if \a["ok"] | a["tag"] <> 4 then return ""
      seq = .LdapBer~readElement(element["value"], a["next"])
      if \seq["ok"] | seq["tag"] <> 48 then return ""
      if seq["next"] <= element["value"]~length then return ""
      initial = .nil; final = .nil; anys = .array~new
      pos = 1
      do while pos <= seq["value"]~length
        part = .LdapBer~readElement(seq["value"], pos)
        if \part["ok"] then return ""
        if part["tag"] = 128 then do
          if initial <> .nil then return ""
          initial = part["value"]
        end
        else if part["tag"] = 129 then anys~append(part["value"])
        else if part["tag"] = 130 then do
          if final <> .nil then return ""
          final = part["value"]
        end
        else return ""
        pos = part["next"]
      end
      out = "(" || a["value"] || "="
      if initial <> .nil then out ||= self~filterEscape(initial)
      out ||= "*"
      do x over anys; out ||= self~filterEscape(x) || "*"; end
      if final <> .nil then out ||= self~filterEscape(final)
      return out || ")"
    end
    when tag = 160 | tag = 161 then do
      content = element["value"]
      offset = 1
      text = "("
      if tag = 160 then text ||= "&"
      else text ||= "|"
      childCount = 0
      do while offset <= content~length
        child = .LdapBer~readElement(content, offset)
        if \child["ok"] then return ""
        part = self~decodeFilter(child)
        if part = "" then return ""
        text ||= part
        childCount += 1
        offset = child["next"]
      end
      if childCount = 0 then return ""
      return text || ")"
    end
    when tag = 162 then do
      child = .LdapBer~readElement(element["value"], 1)
      if \child["ok"] then return ""
      if child["next"] <= element["value"]~length then return ""
      part = self~decodeFilter(child)
      if part = "" then return ""
      return "(!" || part || ")"
    end
    otherwise return ""
  end
::method encodeFilter class
  use strict arg filterText
  parsed = .LdapFilter~parse(filterText)
  if \parsed~ok then raise syntax 88.900 array("unsupported or malformed LDAP filter")
  return self~encodeFilterNode(parsed~value)
::method encodeFilterNode class private
  use strict arg node
  kind = node~kind
  select
    when kind = "AND" | kind = "OR" then do
      body = ""
      do child over node~children; body ||= self~encodeFilterNode(child); end
      if kind = "AND" then return .LdapBer~tlv(160, body)
      return .LdapBer~tlv(161, body)
    end
    when kind = "NOT" then return .LdapBer~tlv(162, self~encodeFilterNode(node~children[1]))
    when kind = "PRESENT" then return .LdapBer~tlv(135, node~attributeName)
    when kind = "EQUALITY" then return .LdapBer~tlv(163, .LdapBer~octet(node~attributeName) || .LdapBer~octet(node~assertionValue))
    when kind = "GE" then return .LdapBer~tlv(165, .LdapBer~octet(node~attributeName) || .LdapBer~octet(node~assertionValue))
    when kind = "LE" then return .LdapBer~tlv(166, .LdapBer~octet(node~attributeName) || .LdapBer~octet(node~assertionValue))
    when kind = "APPROX" then return .LdapBer~tlv(168, .LdapBer~octet(node~attributeName) || .LdapBer~octet(node~assertionValue))
    when kind = "SUBSTRING" then do
      parts = ""
      if node~initial <> .nil then parts ||= .LdapBer~tlv(128, node~initial)
      do x over node~anyParts; parts ||= .LdapBer~tlv(129, x); end
      if node~final <> .nil then parts ||= .LdapBer~tlv(130, node~final)
      return .LdapBer~tlv(164, .LdapBer~octet(node~attributeName) || .LdapBer~sequence(parts))
    end
    otherwise raise syntax 88.900 array("unsupported LDAP filter choice")
  end
::method decodeSearchRequest class
  use strict arg opValue
  out = .directory~new
  base = .LdapBer~readElement(opValue, 1)
  if \base["ok"] | base["tag"] <> 4 then return self~failure("LDAP_SEARCH_BASE_INVALID")
  scope = .LdapBer~readElement(opValue, base["next"])
  deref = .LdapBer~readElement(opValue, scope["next"])
  size = .LdapBer~readElement(opValue, deref["next"])
  time = .LdapBer~readElement(opValue, size["next"])
  types = .LdapBer~readElement(opValue, time["next"])
  if \scope["ok"] | scope["tag"] <> 10 | \deref["ok"] | deref["tag"] <> 10 | \size["ok"] | size["tag"] <> 2 | \time["ok"] | time["tag"] <> 2 | \types["ok"] | types["tag"] <> 1 then return self~failure("LDAP_SEARCH_FIELDS_INVALID")
  filter = .LdapBer~readElement(opValue, types["next"])
  if \filter["ok"] then return filter
  filterText = self~decodeFilter(filter)
  if filterText = "" then return self~failure("LDAP_SEARCH_FILTER_UNSUPPORTED")
  attrs = .LdapBer~readElement(opValue, filter["next"])
  if \attrs["ok"] | attrs["tag"] <> 48 then return self~failure("LDAP_SEARCH_ATTRIBUTES_INVALID")
  names = .array~new
  pos = 1
  do while pos <= attrs["value"]~length
    a = .LdapBer~readElement(attrs["value"], pos)
    if \a["ok"] | a["tag"] <> 4 then return self~failure("LDAP_SEARCH_ATTRIBUTE_INVALID")
    names~append(a["value"])
    pos = a["next"]
  end
  s = .LdapBer~decodeUnsignedInteger(scope["value"])
  if s = 0 then scopeText = "BASE"
  else if s = 1 then scopeText = "ONE"
  else if s = 2 then scopeText = "SUB"
  else return self~failure("LDAP_SEARCH_SCOPE_UNSUPPORTED")
  out["ok"] = .true
  out["baseDn"] = base["value"]
  out["scope"] = scopeText
  out["derefAliases"] = .LdapBer~decodeUnsignedInteger(deref["value"])
  out["sizeLimit"] = .LdapBer~decodeUnsignedInteger(size["value"])
  out["timeLimit"] = .LdapBer~decodeUnsignedInteger(time["value"])
  out["typesOnly"] = types["value"] <> '00'x
  out["filterText"] = filterText
  out["attributes"] = names
  return out
::method encodeSearchRequest class
  use strict arg messageId, baseDn, scope = "SUB", filterText = "(objectClass=*)", attributes = .nil, sizeLimit = 0, timeLimit = 0, typesOnly = .false, controls = .nil
  s = scope~string~upper
  if s = "BASE" then scopeNum = 0
  else if s = "ONE" then scopeNum = 1
  else if s = "SUB" then scopeNum = 2
  else raise syntax 88.900 array("invalid LDAP scope")
  attrsBody = ""
  if attributes <> .nil then do name over attributes
    attrsBody ||= .LdapBer~octet(name)
  end
  content = .LdapBer~octet(baseDn) || .LdapBer~enumerated(scopeNum) || .LdapBer~enumerated(0) || .LdapBer~integer(sizeLimit) || .LdapBer~integer(timeLimit) || .LdapBer~boolean(typesOnly) || self~encodeFilter(filterText) || .LdapBer~sequence(attrsBody)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_SEARCH_REQUEST, content), controls)
::method encodeSearchEntry class
  use strict arg messageId, ldapEntry, typesOnly = .false, controls = .nil
  attrList = ""
  do name over ldapEntry~attributes~names
    values = ""
    if \typesOnly then do value over ldapEntry~attributes~get(name)
      values ||= .LdapBer~octet(value)
    end
    attrList ||= .LdapBer~sequence(.LdapBer~octet(name) || .LdapBer~set(values))
  end
  op = .LdapBer~tlv(self~OP_SEARCH_ENTRY, .LdapBer~octet(ldapEntry~dn) || .LdapBer~sequence(attrList))
  return self~encodeMessage(messageId, op, controls)
::method decodeSearchEntry class
  use strict arg opValue
  dn = .LdapBer~readElement(opValue, 1)
  attrs = .LdapBer~readElement(opValue, dn["next"])
  if \dn["ok"] | dn["tag"] <> 4 | \attrs["ok"] | attrs["tag"] <> 48 then return self~failure("LDAP_SEARCH_ENTRY_INVALID")
  set = .LdapAttributeSet~new
  pos = 1
  do while pos <= attrs["value"]~length
    pa = .LdapBer~readElement(attrs["value"], pos)
    if \pa["ok"] | pa["tag"] <> 48 then return self~failure("LDAP_SEARCH_PARTIAL_ATTRIBUTE_INVALID")
    name = .LdapBer~readElement(pa["value"], 1)
    vals = .LdapBer~readElement(pa["value"], name["next"])
    if \name["ok"] | name["tag"] <> 4 | \vals["ok"] | vals["tag"] <> 49 then return self~failure("LDAP_SEARCH_PARTIAL_ATTRIBUTE_INVALID")
    vp = 1
    do while vp <= vals["value"]~length
      v = .LdapBer~readElement(vals["value"], vp)
      if \v["ok"] | v["tag"] <> 4 then return self~failure("LDAP_SEARCH_VALUE_INVALID")
      set~add(name["value"], v["value"])
      vp = v["next"]
    end
    pos = pa["next"]
  end
  out = .directory~new
  out["ok"] = .true
  out["entry"] = .LdapEntry~new(dn["value"], set)
  return out
::method decodeModifyRequest class
  use strict arg opValue
  dn = .LdapBer~readElement(opValue, 1)
  changes = .LdapBer~readElement(opValue, dn["next"])
  if \dn["ok"] | dn["tag"] <> 4 | \changes["ok"] | changes["tag"] <> 48 then return self~failure("LDAP_MODIFY_INVALID")
  mods = .array~new
  pos = 1
  do while pos <= changes["value"]~length
    change = .LdapBer~readElement(changes["value"], pos)
    if \change["ok"] | change["tag"] <> 48 then return self~failure("LDAP_MODIFY_CHANGE_INVALID")
    op = .LdapBer~readElement(change["value"], 1)
    attr = .LdapBer~readElement(change["value"], op["next"])
    if \op["ok"] | op["tag"] <> 10 | \attr["ok"] | attr["tag"] <> 48 then return self~failure("LDAP_MODIFY_CHANGE_INVALID")
    name = .LdapBer~readElement(attr["value"], 1)
    vals = .LdapBer~readElement(attr["value"], name["next"])
    if \name["ok"] | name["tag"] <> 4 | \vals["ok"] | vals["tag"] <> 49 then return self~failure("LDAP_MODIFY_ATTRIBUTE_INVALID")
    opNum = .LdapBer~decodeUnsignedInteger(op["value"])
    if opNum = 0 then opName = "ADD"
    else if opNum = 1 then opName = "DELETE"
    else if opNum = 2 then opName = "REPLACE"
    else return self~failure("LDAP_MODIFY_OPERATION_INVALID")
    values = .array~new
    vp = 1
    do while vp <= vals["value"]~length
      v = .LdapBer~readElement(vals["value"], vp)
      if \v["ok"] | v["tag"] <> 4 then return self~failure("LDAP_MODIFY_VALUE_INVALID")
      values~append(v["value"])
      vp = v["next"]
    end
    mods~append(.LdapModification~new(opName, name["value"], values))
    pos = change["next"]
  end
  out = .directory~new
  out["ok"] = .true
  out["dn"] = dn["value"]
  out["modifications"] = mods
  return out
::method encodeModifyRequest class
  use strict arg messageId, dn, modifications
  changes = ""
  do m over modifications
    select
      when m~operation = "ADD" then opNum = 0
      when m~operation = "DELETE" then opNum = 1
      when m~operation = "REPLACE" then opNum = 2
      otherwise raise syntax 88.900 array("invalid LDAP modify operation")
    end
    values = ""
    do value over m~values
      values ||= .LdapBer~octet(value)
    end
    partial = .LdapBer~sequence(.LdapBer~octet(m~attributeName) || .LdapBer~set(values))
    changes ||= .LdapBer~sequence(.LdapBer~enumerated(opNum) || partial)
  end
  content = .LdapBer~octet(dn) || .LdapBer~sequence(changes)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_MODIFY_REQUEST, content))
::method decodeAddRequest class
  use strict arg opValue
  dn = .LdapBer~readElement(opValue, 1)
  attrs = .LdapBer~readElement(opValue, dn["next"])
  if \dn["ok"] | dn["tag"] <> 4 | \attrs["ok"] | attrs["tag"] <> 48 then return self~failure("LDAP_ADD_INVALID")
  set = .LdapAttributeSet~new
  pos = 1
  do while pos <= attrs["value"]~length
    pa = .LdapBer~readElement(attrs["value"], pos)
    if \pa["ok"] | pa["tag"] <> 48 then return self~failure("LDAP_ADD_ATTRIBUTE_INVALID")
    name = .LdapBer~readElement(pa["value"],1)
    vals = .LdapBer~readElement(pa["value"],name["next"])
    if \name["ok"] | name["tag"] <> 4 | \vals["ok"] | vals["tag"] <> 49 then return self~failure("LDAP_ADD_ATTRIBUTE_INVALID")
    vp = 1
    do while vp <= vals["value"]~length
      v = .LdapBer~readElement(vals["value"], vp)
      if \v["ok"] | v["tag"] <> 4 then return self~failure("LDAP_ADD_VALUE_INVALID")
      set~add(name["value"], v["value"])
      vp = v["next"]
    end
    pos = pa["next"]
  end
  out = .directory~new; out["ok"] = .true; out["entry"] = .LdapEntry~new(dn["value"], set); return out
::method encodeAddRequest class
  use strict arg messageId, ldapEntry
  attrsBody = ""
  do name over ldapEntry~attributes~names
    values = ""
    do value over ldapEntry~attributes~get(name)
      values ||= .LdapBer~octet(value)
    end
    attrsBody ||= .LdapBer~sequence(.LdapBer~octet(name) || .LdapBer~set(values))
  end
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_ADD_REQUEST, .LdapBer~octet(ldapEntry~dn) || .LdapBer~sequence(attrsBody)))
::method decodeCompareRequest class
  use strict arg opValue
  dn = .LdapBer~readElement(opValue,1)
  ava = .LdapBer~readElement(opValue,dn["next"])
  if \dn["ok"] | dn["tag"] <> 4 | \ava["ok"] | ava["tag"] <> 48 then return self~failure("LDAP_COMPARE_INVALID")
  name = .LdapBer~readElement(ava["value"],1)
  value = .LdapBer~readElement(ava["value"],name["next"])
  if \name["ok"] | name["tag"] <> 4 | \value["ok"] | value["tag"] <> 4 then return self~failure("LDAP_COMPARE_INVALID")
  out = .directory~new; out["ok"] = .true; out["dn"] = dn["value"]; out["attribute"] = name["value"]; out["value"] = value["value"]; return out
::method encodeCompareRequest class
  use strict arg messageId, dn, attributeName, assertionValue
  ava = .LdapBer~sequence(.LdapBer~octet(attributeName) || .LdapBer~octet(assertionValue))
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_COMPARE_REQUEST, .LdapBer~octet(dn) || ava))
::method decodeModifyDnRequest class
  use strict arg opValue
  dn = .LdapBer~readElement(opValue,1)
  rdn = .LdapBer~readElement(opValue,dn["next"])
  del = .LdapBer~readElement(opValue,rdn["next"])
  if \dn["ok"] | dn["tag"] <> 4 | \rdn["ok"] | rdn["tag"] <> 4 | \del["ok"] | del["tag"] <> 1 then return self~failure("LDAP_MODDN_INVALID")
  superior = ""
  if del["next"] <= opValue~length then do
    sup = .LdapBer~readElement(opValue, del["next"])
    if \sup["ok"] | sup["tag"] <> 128 then return self~failure("LDAP_MODDN_SUPERIOR_INVALID")
    superior = sup["value"]
  end
  out = .directory~new; out["ok"] = .true; out["dn"] = dn["value"]; out["newRdn"] = rdn["value"]; out["deleteOldRdn"] = del["value"] <> '00'x; out["newSuperior"] = superior; return out
::method encodeModifyDnRequest class
  use strict arg messageId, dn, newRdn, deleteOldRdn = .true, newSuperior = ""
  content = .LdapBer~octet(dn) || .LdapBer~octet(newRdn) || .LdapBer~boolean(deleteOldRdn)
  if newSuperior <> "" then content ||= .LdapBer~tlv(128, newSuperior)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_MODDN_REQUEST, content))
::method decodeExtendedRequest class
  use strict arg opValue
  name = .LdapBer~readElement(opValue, 1)
  if \name["ok"] | name["tag"] <> 128 then return self~failure("LDAP_EXTENDED_NAME_INVALID")
  value = .nil
  if name["next"] <= opValue~length then do
    v = .LdapBer~readElement(opValue, name["next"])
    if \v["ok"] | v["tag"] <> 129 then return self~failure("LDAP_EXTENDED_VALUE_INVALID")
    value = v["value"]
    if v["next"] <= opValue~length then return self~failure("LDAP_EXTENDED_TRAILING_BYTES")
  end
  out = .directory~new; out["ok"] = .true; out["requestName"] = name["value"]; out["requestValue"] = value; return out
::method encodeExtendedRequest class
  use strict arg messageId, requestName, requestValue = .nil, controls = .nil
  body = .LdapBer~tlv(128, requestName)
  if requestValue <> .nil then body ||= .LdapBer~tlv(129, requestValue)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_EXTENDED_REQUEST, body), controls)
::method encodeExtendedResponse class
  use strict arg messageId, resultCode, matchedDn = "", diagnostic = "", responseName = .nil, responseValue = .nil, controls = .nil
  body = .LdapBer~enumerated(resultCode) || .LdapBer~octet(matchedDn) || .LdapBer~octet(diagnostic)
  if responseName <> .nil then body ||= .LdapBer~tlv(138, responseName)
  if responseValue <> .nil then body ||= .LdapBer~tlv(139, responseValue)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_EXTENDED_RESPONSE, body), controls)
::method encodeIntermediateResponse class
  use strict arg messageId, responseName = .nil, responseValue = .nil, controls = .nil
  body = ""
  if responseName <> .nil then body ||= .LdapBer~tlv(128, responseName)
  if responseValue <> .nil then body ||= .LdapBer~tlv(129, responseValue)
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_INTERMEDIATE_RESPONSE, body), controls)
::method decodeIntermediateResponse class
  use strict arg opValue
  out = .directory~new; out["ok"] = .true; out["responseName"] = .nil; out["responseValue"] = .nil
  pos = 1
  do while pos <= opValue~length
    e = .LdapBer~readElement(opValue, pos)
    if \e["ok"] then return e
    if e["tag"] = 128 then do
      if out["responseName"] <> .nil then return self~failure("LDAP_INTERMEDIATE_DUPLICATE_NAME")
      out["responseName"] = e["value"]
    end
    else if e["tag"] = 129 then do
      if out["responseValue"] <> .nil then return self~failure("LDAP_INTERMEDIATE_DUPLICATE_VALUE")
      out["responseValue"] = e["value"]
    end
    else return self~failure("LDAP_INTERMEDIATE_FIELD_INVALID")
    pos = e["next"]
  end
  return out
::method decodeExtendedResponse class
  use strict arg opValue
  base = self~decodeResult(opValue)
  if \base["ok"] then return base
  codeEl = .LdapBer~readElement(opValue, 1)
  dnEl = .LdapBer~readElement(opValue, codeEl["next"])
  diagEl = .LdapBer~readElement(opValue, dnEl["next"])
  pos = diagEl["next"]
  base["responseName"] = .nil
  base["responseValue"] = .nil
  do while pos <= opValue~length
    e = .LdapBer~readElement(opValue, pos)
    if \e["ok"] then return e
    if e["tag"] = 138 then base["responseName"] = e["value"]
    else if e["tag"] = 139 then base["responseValue"] = e["value"]
    else return self~failure("LDAP_EXTENDED_RESPONSE_FIELD_INVALID")
    pos = e["next"]
  end
  return base
::method encodeDeleteRequest class
  use strict arg messageId, dn
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_DELETE_REQUEST, dn))
::method encodeUnbindRequest class
  use strict arg messageId
  return self~encodeMessage(messageId, .LdapBer~tlv(self~OP_UNBIND_REQUEST, ""))

::requires "src/LdapDirectoryPersonality.cls"
