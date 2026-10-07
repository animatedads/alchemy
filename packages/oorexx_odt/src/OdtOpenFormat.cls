/* OdtOpenFormat.cls - native package-level ODT reader/writer. */

::class OdtReader public
::method open class
  use strict arg path
  return .OdtPackageReader~new~read(path)

::class OdtWriter public
::method write class
  use strict arg document, path
  if \document~isA(.OdtDocument) then raise syntax 93.900 array("ODT writer requires OdtDocument")
  return .OdtPackageWriter~new~write(document, path)

::class OdtPackageSupport public
::method shellQuote
  use strict arg value
  return "'" || changestr("'", value, "'\\''") || "'"
::method readText
  use strict arg path
  s = .Stream~new(path)
  if s~open("read") \== "READY:" then return ""
  n = s~chars
  data = ""
  if n > 0 then data = s~charin(1, n)
  s~close
  return data
::method writeText
  use strict arg path, data
  s = .Stream~new(path)
  state = s~open("write replace")
  if state \== "READY:" then raise syntax 93.900 array("Could not write" path)
  s~charout(data)
  s~close
::method joinPath
  use strict arg root, relative
  if right(root, 1) == "/" then return root || relative
  return root || "/" || relative
::method removeTree
  use strict arg path
  if strip(path) == "" then return
  address system "rm -rf --" self~shellQuote(path)

::class OdtPackageReader subclass OdtPackageSupport public
::method read
  use strict arg path
  tmp = SysTempFileName("/tmp/oorexx_odt_????????")
  address system "mkdir -p" self~shellQuote(tmp)
  if rc \== 0 then raise syntax 93.900 array("Could not allocate ODT work directory")
  address system "unzip -qq -o" self~shellQuote(path) "-d" self~shellQuote(tmp)
  if rc \== 0 then do
    self~removeTree(tmp)
    raise syntax 93.900 array("Could not unpack ODT package:" path)
  end
  signal on syntax name cleanupError
  signal on error name cleanupError
  mimetype = strip(self~readText(self~joinPath(tmp, "mimetype")))
  if mimetype \== "application/vnd.oasis.opendocument.text" then -
    raise syntax 93.900 array("Not an OpenDocument Text package:" mimetype)
  content = self~readText(self~joinPath(tmp, "content.xml"))
  if content == "" then raise syntax 93.900 array("ODT content.xml is missing")
  meta = self~readText(self~joinPath(tmp, "meta.xml"))
  title = .OdtXml~firstText(meta, "dc:title")
  creator = .OdtXml~firstText(meta, "dc:creator")
  document = .OdtDocument~new(title, creator)
  document~sourcePath = path
  self~readBlocks(content, document)
  self~removeTree(tmp)
  return document
cleanupError:
  say "ODT package read failed:" condition("C") condition("D") "RC=" rc "SIGL=" sigl
  self~removeTree(tmp)
  raise propagate

::method readBlocks
  use strict arg xml, document
  startTag = "<office:text"
  startPos = pos(startTag, xml)
  if startPos == 0 then return
  startEnd = pos(">", xml, startPos)
  endPos = pos("</office:text>", xml, startEnd + 1)
  if endPos == 0 then endPos = length(xml) + 1
  body = substr(xml, startEnd + 1, endPos - startEnd - 1)
  cursor = 1
  do while cursor <= length(body)
    nextH = .OdtXml~nextTag(body, "text:h", cursor)
    nextP = .OdtXml~nextTag(body, "text:p", cursor)
    nextT = .OdtXml~nextTag(body, "table:table", cursor)
    which = .OdtXml~minimumTagged(nextH, "H", nextP, "P", nextT, "T")
    if which == .nil then leave
    at = which~at(1)
    kind = which~at(2)
    if kind == "H" then do
      block = .OdtXml~blockAt(body, "text:h", at)
      if block == "" then leave
      tag = .OdtXml~openingTag(block)
      levelText = .OdtXml~attribute(tag, "text:outline-level")
      level = 1
      if datatype(levelText, "W") then level = levelText
      styleName = .OdtXml~attribute(tag, "text:style-name")
      document~addHeading(.OdtXml~inlineText(block), level, styleName)
      cursor = at + length(block)
    end
    else if kind == "P" then do
      block = .OdtXml~blockAt(body, "text:p", at)
      if block == "" then leave
      tag = .OdtXml~openingTag(block)
      styleName = .OdtXml~attribute(tag, "text:style-name")
      document~addParagraph(.OdtXml~inlineText(block), styleName)
      cursor = at + length(block)
    end
    else do
      block = .OdtXml~blockAt(body, "table:table", at)
      if block == "" then leave
      document~addTable(self~readTable(block))
      cursor = at + length(block)
    end
  end

::method readTable
  use strict arg block
  tag = .OdtXml~openingTag(block)
  name = .OdtXml~attribute(tag, "table:name")
  if name == "" then name = "Table"
  table = .OdtTable~new(name)
  rows = .OdtXml~elementBlocks(block, "table:table-row")
  loop r = 1 to rows~items
    rowBlock = rows~at(r)
    cells = .OdtXml~elementBlocks(rowBlock, "table:table-cell")
    row = .Array~new
    loop c = 1 to cells~items
      cellBlock = cells~at(c)
      repeatText = .OdtXml~attribute(.OdtXml~openingTag(cellBlock), "table:number-columns-repeated")
      repeat = 1
      if datatype(repeatText, "W") then repeat = repeatText
      value = .OdtXml~cellText(cellBlock)
      loop k = 1 to repeat
        row~append(value)
      end
    end
    table~addRow(row)
  end
  return table

::class OdtPackageWriter subclass OdtPackageSupport public
::method write
  use strict arg document, path
  if left(path, 1) \== "/" then path = directory() || "/" || path
  tmp = SysTempFileName("/tmp/oorexx_odt_write_????????")
  address system "mkdir -p" self~shellQuote(tmp) self~shellQuote(tmp || "/META-INF")
  if rc \== 0 then raise syntax 93.900 array("Could not allocate ODT write directory")
  signal on syntax name cleanupError
  signal on error name cleanupError
  self~writeText(tmp || "/mimetype", "application/vnd.oasis.opendocument.text")
  self~writeText(tmp || "/content.xml", self~contentXml(document))
  self~writeText(tmp || "/styles.xml", self~stylesXml)
  self~writeText(tmp || "/meta.xml", self~metaXml(document))
  self~writeText(tmp || "/settings.xml", self~settingsXml)
  self~writeText(tmp || "/META-INF/manifest.xml", self~manifestXml)
  address system "rm -f --" self~shellQuote(path)
  if rc \== 0 then nop
  old = directory()
  call directory tmp
  address system "zip -q -0" self~shellQuote(path) "mimetype"
  if rc \== 0 then do
    call directory old
    raise syntax 93.900 array("Could not create ODT package")
  end
  address system "zip -q -r" self~shellQuote(path) "content.xml styles.xml meta.xml settings.xml META-INF"
  zipRc = rc
  call directory old
  if zipRc \== 0 then raise syntax 93.900 array("Could not complete ODT package")
  self~removeTree(tmp)
  return path
cleanupError:
  say "ODT package write failed:" condition("C") condition("D") "RC=" rc "SIGL=" sigl
  self~removeTree(tmp)
  raise propagate

::method contentXml
  use strict arg document
  body = ""
  blocks = document~blocks
  loop i = 1 to blocks~items
    b = blocks~at(i)
    if b~isA(.OdtHeading) then do
      style = ""
      if b~styleName \== "" then style = ' text:style-name="' || .OdtXml~encode(b~styleName) || '"'
      body = body || '<text:h text:outline-level="' || b~level || '"' || style || '>' || .OdtXml~encode(b~text) || '</text:h>' || .endOfLine
    end
    else if b~isA(.OdtParagraph) then do
      style = ""
      if b~styleName \== "" then style = ' text:style-name="' || .OdtXml~encode(b~styleName) || '"'
      body = body || '<text:p' || style || '>' || .OdtXml~encode(b~text) || '</text:p>' || .endOfLine
    end
    else if b~isA(.OdtTable) then body = body || self~tableXml(b)
  end
  return '<?xml version="1.0" encoding="UTF-8"?>' || .endOfLine || -
    '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" office:version="1.3">' || .endOfLine || -
    '<office:automatic-styles/>' || .endOfLine || '<office:body><office:text>' || .endOfLine || body || '</office:text></office:body></office:document-content>' || .endOfLine
::method tableXml
  use strict arg table
  out = '<table:table table:name="' || .OdtXml~encode(table~name) || '">' || .endOfLine
  rows = table~rows
  loop r = 1 to rows~items
    out = out || '<table:table-row>'
    row = rows~at(r)
    loop c = 1 to row~items
      out = out || '<table:table-cell office:value-type="string"><text:p>' || .OdtXml~encode(row~at(c)) || '</text:p></table:table-cell>'
    end
    out = out || '</table:table-row>' || .endOfLine
  end
  return out || '</table:table>' || .endOfLine
::method metaXml
  use strict arg document
  return '<?xml version="1.0" encoding="UTF-8"?>' || .endOfLine || -
    '<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" office:version="1.3"><office:meta><dc:title>' || .OdtXml~encode(document~title) || '</dc:title><dc:creator>' || .OdtXml~encode(document~creator) || '</dc:creator><meta:generator>ooRexx ODT v0.1-dev1</meta:generator></office:meta></office:document-meta>' || .endOfLine
::method stylesXml
  return '<?xml version="1.0" encoding="UTF-8"?>' || .endOfLine || -
    '<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3"><office:styles/></office:document-styles>' || .endOfLine
::method settingsXml
  return '<?xml version="1.0" encoding="UTF-8"?>' || .endOfLine || -
    '<office:document-settings xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" office:version="1.3"><office:settings/></office:document-settings>' || .endOfLine
::method manifestXml
  return '<?xml version="1.0" encoding="UTF-8"?>' || .endOfLine || -
    '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3"><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/><manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/><manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/><manifest:file-entry manifest:full-path="settings.xml" manifest:media-type="text/xml"/></manifest:manifest>' || .endOfLine

::class OdtXml public
::method attribute class
  use strict arg tag, name
  marker = name || "="
  p = pos(marker, tag)
  if p == 0 then return ""
  p = p + length(marker)
  if p > length(tag) then return ""
  quote = substr(tag, p, 1)
  if quote \== '"' then do
    if quote \== "'" then return ""
  end
  q = pos(quote, tag, p + 1)
  if q == 0 then return ""
  return self~decode(substr(tag, p + 1, q - p - 1))
::method nextTag class
  use strict arg xml, name, start = 1
  marker = "<" || name
  p = pos(marker, xml, start)
  do while p > 0
    after = p + length(marker)
    if after > length(xml) then return p
    d = substr(xml, after, 1)
    if d == " " | d == ">" | d == "/" | d == "09"x | d == .endOfLine then return p
    p = pos(marker, xml, after)
  end
  return 0
::method minimumTagged class
  use strict arg p1, k1, p2, k2, p3, k3
  best = 0
  kind = ""
  if p1 > 0 then do; best = p1; kind = k1; end
  if p2 > 0 then do
    if best == 0 then do; best = p2; kind = k2; end
    else if p2 < best then do; best = p2; kind = k2; end
  end
  if p3 > 0 then do
    if best == 0 then do; best = p3; kind = k3; end
    else if p3 < best then do; best = p3; kind = k3; end
  end
  if best == 0 then return .nil
  return .Array~of(best, kind)
::method openingTag class
  use strict arg block
  q = pos(">", block)
  if q == 0 then return block
  return substr(block, 1, q)
::method blockAt class
  use strict arg xml, name, start
  openEnd = pos(">", xml, start)
  if openEnd == 0 then return ""
  if substr(xml, openEnd - 1, 2) == "/>" then return substr(xml, start, openEnd - start + 1)
  close = "</" || name || ">"
  closePos = pos(close, xml, openEnd + 1)
  if closePos == 0 then return ""
  return substr(xml, start, closePos + length(close) - start)
::method elementBlocks class
  use strict arg xml, name
  out = .Array~new
  cursor = 1
  do while cursor <= length(xml)
    p = self~nextTag(xml, name, cursor)
    if p == 0 then leave
    block = self~blockAt(xml, name, p)
    if block == "" then leave
    out~append(block)
    cursor = p + length(block)
  end
  return out
::method firstText class
  use strict arg xml, name
  p = self~nextTag(xml, name, 1)
  if p == 0 then return ""
  b = self~blockAt(xml, name, p)
  if b == "" then return ""
  return self~inlineText(b)
::method cellText class
  use strict arg block
  ps = self~elementBlocks(block, "text:p")
  out = ""
  loop i = 1 to ps~items
    if i > 1 then out = out || .endOfLine
    out = out || self~inlineText(ps~at(i))
  end
  return out
::method inlineText class
  use strict arg block
  openEnd = pos(">", block)
  closeStart = lastpos("</", block)
  if openEnd == 0 then return ""
  if closeStart <= openEnd then return ""
  value = substr(block, openEnd + 1, closeStart - openEnd - 1)
  value = changestr("<text:tab/>", value, "09"x)
  value = changestr("<text:line-break/>", value, .endOfLine)
  value = self~expandSpaces(value)
  value = self~stripTags(value)
  return self~decode(value)
::method expandSpaces class
  use strict arg text
  value = text
  cursor = 1
  do forever
    p = pos("<text:s", value, cursor)
    if p == 0 then leave
    q = pos(">", value, p)
    if q == 0 then leave
    tag = substr(value, p, q - p + 1)
    countText = self~attribute(tag, "text:c")
    count = 1
    if datatype(countText, "W") then count = countText
    spaces = copies(" ", count)
    value = substr(value, 1, p - 1) || spaces || substr(value, q + 1)
    cursor = p + length(spaces)
  end
  return value
::method stripTags class
  use strict arg text
  out = ""
  cursor = 1
  do while cursor <= length(text)
    p = pos("<", text, cursor)
    if p == 0 then do; out = out || substr(text, cursor); leave; end
    if p > cursor then out = out || substr(text, cursor, p - cursor)
    q = pos(">", text, p + 1)
    if q == 0 then leave
    cursor = q + 1
  end
  return out
::method encode class
  use strict arg text
  value = changestr("&", text, "&amp;")
  value = changestr("<", value, "&lt;")
  value = changestr(">", value, "&gt;")
  value = changestr('"', value, "&quot;")
  value = changestr("'", value, "&apos;")
  return value
::method decode class
  use strict arg text
  value = changestr("&lt;", text, "<")
  value = changestr("&gt;", value, ">")
  value = changestr("&quot;", value, '"')
  value = changestr("&apos;", value, "'")
  value = changestr("&amp;", value, "&")
  return value

::requires "OdtModel.cls"
