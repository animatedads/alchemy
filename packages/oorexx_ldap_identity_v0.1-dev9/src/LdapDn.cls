/* LdapDn.cls
 * RFC 4514-oriented distinguished-name syntax support for the LDAP edge.
 *
 * The Identity Directory continues to treat DN text as an externally visible
 * locator.  This class owns LDAP parsing, escaping and structural comparison;
 * it does not make LDAP DN syntax the platform identity authority.
 *
 * Comparison uses the directory's current case-ignore string profile because
 * a complete LDAP matching-rule engine is not yet present.  The parser and
 * serializer handle escaped separators, hex escapes, multi-valued RDNs and
 * hexstring values.  Attribute-specific matching rules remain a later schema
 * capability and are therefore not claimed here.
 */

::class LdapDnBuild public
::constant API_VERSION "ldap.dn/0.1"
::constant COMPARISON_PROFILE "oorexx-ldap-dn-case-ignore/0.1"

::class LdapDnAva public
::attribute attributeType get
::attribute value get
::attribute hexString get
::method init
  expose attributeType value hexString
  use strict arg typeArg, valueArg, hexArg = .false
  attributeType = typeArg~string~lower
  value = valueArg~string
  hexString = hexArg
::method canonicalKey
  expose attributeType value hexString
  if hexString then return attributeType || "=#" || c2x(value)~lower
  return attributeType || "=" || value~lower
::method canonicalText
  expose attributeType value hexString
  if hexString then return attributeType || "=#" || c2x(value)~lower
  return attributeType || "=" || .LdapDn~escapeValue(value)

::class LdapDnRdn public
::attribute avas get
::method init
  expose avas
  use strict arg avasArg
  avas = .DirectoryCanonical~copyArray(avasArg)
::method canonicalKeys
  expose avas
  keys = .array~new
  do ava over avas
    keys~append(ava~canonicalKey)
  end
  return .DirectoryCanonical~sortedStrings(keys)
::method canonicalKey
  keys = self~canonicalKeys
  out = ""
  do i = 1 to keys~items
    if i > 1 then out ||= "+"
    out ||= keys[i]
  end
  return out
::method canonicalText
  expose avas
  /* RDN is a SET.  Sort AVAs for a deterministic LDAP-edge rendering. */
  byKey = .directory~new
  keys = .array~new
  do ava over avas
    key = ava~canonicalKey
    n = key
    serial = 0
    do while byKey~hasIndex(n)
      serial += 1
      n = key || "#" || serial
    end
    byKey[n] = ava
    keys~append(n)
  end
  keys = .DirectoryCanonical~sortedStrings(keys)
  out = ""
  do i = 1 to keys~items
    if i > 1 then out ||= "+"
    out ||= byKey[keys[i]]~canonicalText
  end
  return out

::class LdapDn public
::attribute rdns get
::attribute source get
::method init
  expose rdns source
  use strict arg sourceArg
  source = sourceArg~string
  rdns = .array~new
  if source = "" then return
  parts = self~splitUnescaped(source, ",")
  if parts == .nil then raise syntax 88.900 array("invalid LDAP DN")
  if parts~items = 0 then raise syntax 88.900 array("invalid LDAP DN")
  do part over parts
    if part = "" then raise syntax 88.900 array("empty LDAP RDN")
    avaParts = self~splitUnescaped(part, "+")
    if avaParts == .nil then raise syntax 88.900 array("invalid LDAP RDN")
    if avaParts~items = 0 then raise syntax 88.900 array("invalid LDAP RDN")
    avas = .array~new
    do avaText over avaParts
      avas~append(self~parseAva(avaText))
    end
    rdns~append(.LdapDnRdn~new(avas))
  end
::method parse class
  use strict arg text
  signal on syntax name invalid
  dn = self~new(text)
  signal off syntax
  return .DirectoryResult~success(dn)
invalid:
  signal off syntax
  return .DirectoryResult~failure("LDAP_INVALID_DN", text~string)
::method isValid class
  use strict arg text
  return self~parse(text)~ok
::method canonical class
  use strict arg text
  p = self~parse(text)
  if \p~ok then return ""
  return p~value~canonicalText
::method equivalent class
  use strict arg left, right
  lp = self~parse(left)
  rp = self~parse(right)
  if \lp~ok | \rp~ok then return .false
  return lp~value~canonicalKey = rp~value~canonicalKey
::method findEntity class
  use strict arg directory, dn
  do entity over directory~allEntries
    if self~equivalent(entity~dn, dn) then return entity
  end
  return .nil
::method canonicalKey
  expose rdns
  out = ""
  do i = 1 to rdns~items
    if i > 1 then out ||= ","
    out ||= rdns[i]~canonicalKey
  end
  return out
::method canonicalText
  expose rdns
  out = ""
  do i = 1 to rdns~items
    if i > 1 then out ||= ","
    out ||= rdns[i]~canonicalText
  end
  return out
::method depth
  expose rdns
  return rdns~items
::method parentText
  expose rdns
  if rdns~items <= 1 then return ""
  out = ""
  do i = 2 to rdns~items
    if i > 2 then out ||= ","
    out ||= rdns[i]~canonicalText
  end
  return out
::method isDescendantOf
  expose rdns
  use strict arg baseDn, allowEqual = .true
  bp = .LdapDn~parse(baseDn)
  if \bp~ok then return .false
  b = bp~value
  if rdns~items < b~rdns~items then return .false
  if \allowEqual & rdns~items = b~rdns~items then return .false
  offset = rdns~items - b~rdns~items
  do i = 1 to b~rdns~items
    if rdns[i + offset]~canonicalKey <> b~rdns[i]~canonicalKey then return .false
  end
  return .true
::method relativeDepth
  expose rdns
  use strict arg baseDn
  bp = .LdapDn~parse(baseDn)
  if \bp~ok then return -1
  b = bp~value
  if \self~isDescendantOf(b~canonicalText, .true) then return -1
  return rdns~items - b~rdns~items
::method compose class
  use strict arg rdnText, superiorDn = ""
  rp = self~parse(rdnText)
  if \rp~ok | rp~value~depth <> 1 then return .DirectoryResult~failure("LDAP_INVALID_RDN", rdnText~string)
  if superiorDn~string = "" then return .DirectoryResult~success(rp~value~canonicalText)
  sp = self~parse(superiorDn)
  if \sp~ok then return .DirectoryResult~failure("LDAP_INVALID_DN", superiorDn~string)
  return .DirectoryResult~success(rp~value~canonicalText || "," || sp~value~canonicalText)
::method parseAva private
  use strict arg text
  eq = self~firstUnescaped(text, "=")
  if eq <= 1 then raise syntax 88.900 array("LDAP AVA requires attribute type and value")
  attr = text~left(eq - 1)~strip
  if \.LdapDn~validAttributeType(attr) then raise syntax 88.900 array("invalid LDAP attribute type")
  raw = text~substr(eq + 1)
  if raw~left(1) = "#" then do
    hex = raw~substr(2)
    if hex = "" | (hex~length // 2) <> 0 | \.LdapDn~allHex(hex) then raise syntax 88.900 array("invalid LDAP hexstring")
    return .LdapDnAva~new(attr, x2c(hex), .true)
  end
  /* RFC 4514 requires leading/trailing spaces and a leading # to be escaped. */
  if raw <> "" then do
    if raw~left(1) = " " | raw~right(1) = " " | raw~left(1) = "#" then raise syntax 88.900 array("LDAP DN value requires escaping")
  end
  return .LdapDnAva~new(attr, .LdapDn~decodeEscapes(raw), .false)
::method splitUnescaped private
  use strict arg text, delimiter
  out = .array~new
  start = 1
  escaped = .false
  i = 1
  do while i <= text~length
    c = text~substr(i, 1)
    if escaped then escaped = .false
    else if c = "\" then escaped = .true
    else if c = delimiter then do
      out~append(text~substr(start, i - start))
      start = i + 1
    end
    i += 1
  end
  if escaped then raise syntax 88.900 array("trailing LDAP escape")
  out~append(text~substr(start))
  return out
::method firstUnescaped private
  use strict arg text, token
  escaped = .false
  do i = 1 to text~length
    c = text~substr(i, 1)
    if escaped then escaped = .false
    else if c = "\" then escaped = .true
    else if c = token then return i
  end
  if escaped then raise syntax 88.900 array("trailing LDAP escape")
  return 0
::method decodeEscapes class
  use strict arg raw
  out = ""
  i = 1
  do while i <= raw~length
    c = raw~substr(i,1)
    if c <> "\" then do
      out ||= c
      i += 1
      iterate
    end
    if i = raw~length then raise syntax 88.900 array("trailing LDAP escape")
    if i + 2 <= raw~length then do
      pair = raw~substr(i + 1, 2)
      if self~allHex(pair) then do
        out ||= x2c(pair)
        i += 3
        iterate
      end
    end
    out ||= raw~substr(i + 1, 1)
    i += 2
  end
  return out
::method escapeValue class
  use strict arg value
  value = value~string
  out = ""
  do i = 1 to value~length
    c = value~substr(i,1)
    n = c2d(c)
    escape = .false
    if c = "," | c = "+" | c = '"' | c = "\" | c = "<" | c = ">" | c = ";" then escape = .true
    if i = 1 & (c = " " | c = "#") then escape = .true
    if i = value~length & c = " " then escape = .true
    if n = 0 | n < 32 | n >= 127 then out ||= "\" || d2x(n,2)~lower
    else if escape then out ||= "\" || c
    else out ||= c
  end
  return out
::method allHex class
  use strict arg text
  if text = "" then return .false
  do i = 1 to text~length
    if "0123456789abcdefABCDEF"~pos(text~substr(i,1)) = 0 then return .false
  end
  return .true
::method validAttributeType class
  use strict arg text
  if text = "" then return .false
  if text~verify("0123456789.") = 0 then do
    if text~left(1) = "." | text~right(1) = "." then return .false
    return .true
  end
  first = text~left(1)
  if ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"~pos(first)) = 0 then return .false
  do i = 2 to text~length
    c = text~substr(i,1)
    if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"~pos(c) = 0 then return .false
  end
  return .true

::requires "src/IdentityDirectory.cls"
