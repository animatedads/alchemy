/* OdtAccess.cls - Spiral 1 COTS access route for OpenDocument Text. */

::class OdtAccess public
::method open class
  use strict arg path
  return .OdtReader~open(path)
::method create class
  use strict arg title = "", creator = ""
  return .OdtDocument~new(title, creator)
::method save class
  use strict arg document, path
  return .OdtWriter~write(document, path)
::method capabilities class
  out = .Array~new
  out~append("ODT.OPEN")
  out~append("ODT.CREATE")
  out~append("ODT.SAVE")
  out~append("ODT.READ_TEXT")
  out~append("ODT.READ_HEADINGS")
  out~append("ODT.READ_TABLES")
  return out
::method describe class
  use strict arg document
  d = .Directory~new
  d["FORMAT"] = document~format
  d["TITLE"] = document~title
  d["CREATOR"] = document~creator
  d["BLOCKS"] = document~blocks~items
  d["HEADINGS"] = document~headings~items
  d["PARAGRAPHS"] = document~paragraphs~items
  d["TABLES"] = document~tables~items
  d["SOURCE"] = document~sourcePath
  return d

::class OdtIntentionAccess public
::method discover class
  use strict arg document
  out = .Array~new
  out~append(.OdtAccessIntention~new("DESCRIBE_DOCUMENT", "describe document", "READ_ONLY"))
  if document~headings~items > 0 then out~append(.OdtAccessIntention~new("LIST_HEADINGS", "list document headings", "READ_ONLY"))
  if document~tables~items > 0 then out~append(.OdtAccessIntention~new("LIST_TABLES", "list document tables", "READ_ONLY"))
  if document~paragraphs~items > 0 then out~append(.OdtAccessIntention~new("READ_TEXT", "read document text", "READ_ONLY"))
  return out

::class OdtAccessIntention public
::method init
  expose id meaning mode
  use strict arg id, meaning, mode
::attribute id get
::attribute meaning get
::attribute mode get

::requires "OdtOpenFormat.cls"
