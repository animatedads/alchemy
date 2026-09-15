/* CivicPort v0.3 URL allow-list.  No caller gets arbitrary network reach. */

::class CivicUrlParts subclass CivicAlchemyObject public
::attribute scheme get
::attribute host get
::attribute port get
::attribute path get
::attribute query get
::attribute original get

::method parse class
  use arg url
  text = url~string
  schemeEnd = text~pos("://")
  if schemeEnd <= 1 then return .nil
  scheme = text~left(schemeEnd - 1)~lower
  rest = text~substr(schemeEnd + 3)
  if rest = "" then return .nil
  if rest~pos("#") > 0 then return .nil

  slash = rest~pos("/")
  queryAt = rest~pos("?")
  if slash = 0 | (queryAt > 0 & queryAt < slash) then do
    if queryAt > 0 then do
      authority = rest~left(queryAt - 1)
      pathQuery = "/" || rest~substr(queryAt)
    end
    else do
      authority = rest
      pathQuery = "/"
    end
  end
  else do
    authority = rest~left(slash - 1)
    pathQuery = rest~substr(slash)
  end
  if authority = "" | authority~pos("@") > 0 then return .nil
  if authority~pos("[") > 0 | authority~pos("]") > 0 then return .nil

  colon = authority~lastPos(":")
  if colon > 0 then do
    host = authority~left(colon - 1)~lower
    port = authority~substr(colon + 1)
    if host = "" | port = "" | \datatype(port, "W") then return .nil
  end
  else do
    host = authority~lower
    port = ""
  end

  qmark = pathQuery~pos("?")
  if qmark > 0 then do
    path = pathQuery~left(qmark - 1)
    query = pathQuery~substr(qmark + 1)
  end
  else do
    path = pathQuery
    query = ""
  end
  if path = "" then path = "/"
  return .CivicUrlParts~new(scheme, host, port, path, query, text)

::method init
  expose scheme host port path query original
  use arg schemeArg, hostArg, portArg, pathArg, queryArg, originalArg
  ignore = self~initCivicAlchemy
  scheme = schemeArg
  host = hostArg
  port = portArg
  path = pathArg
  query = queryArg
  original = originalArg


::class CivicEndpointTemplate subclass CivicAlchemyObject public
::attribute scheme get
::attribute host get
::attribute port get
::attribute pathTemplate get
::attribute allowQuery get
::attribute queryTemplate get

::method init
  expose scheme host port pathTemplate allowQuery queryTemplate
  use arg schemeArg, hostArg, pathArg, allowQueryArg = .false, portArg = "", queryTemplateArg = ""
  ignore = self~initCivicAlchemy
  scheme = schemeArg~string~lower
  host = hostArg~string~lower
  pathTemplate = pathArg~string
  allowQuery = allowQueryArg
  port = portArg~string
  queryTemplate = queryTemplateArg~string
  if pathTemplate~left(1) \= "/" then raise syntax 93.900 additional("Civic endpoint path template must start with /")
  if queryTemplate \= "" & \allowQuery then raise syntax 93.900 additional("Civic endpoint query template requires allowQuery")

::method matches
  expose scheme host port pathTemplate allowQuery queryTemplate
  use arg parts
  if parts == .nil then return .false
  if parts~scheme \== scheme then return .false
  if parts~host \== host then return .false
  expectedPort = port
  actualPort = parts~port
  if expectedPort = "" then do
    if scheme = "https" then expectedPort = "443"
    else if scheme = "http" then expectedPort = "80"
  end
  if actualPort = "" then do
    if parts~scheme = "https" then actualPort = "443"
    else if parts~scheme = "http" then actualPort = "80"
  end
  if actualPort \== expectedPort then return .false
  if queryTemplate \= "" then do
    if \self~queryMatches(queryTemplate, parts~query) then return .false
  end
  else if \allowQuery & parts~query \= "" then return .false
  return self~pathMatches(pathTemplate, parts~path)


::method queryMatches private
  use arg template, actual
  if template = "" then return actual = ""
  if actual = "" then return .false
  wantedParts = self~queryParts(template)
  actualParts = self~queryParts(actual)
  if wantedParts == .nil | actualParts == .nil then return .false
  if wantedParts~items \= actualParts~items then return .false
  do i = 1 to wantedParts~items
    wanted = wantedParts[i]
    got = actualParts[i]
    if wanted[1] \== got[1] then return .false
    wantedValue = wanted[2]
    gotValue = got[2]
    if wantedValue~left(1) = "{" & wantedValue~right(1) = "}" then do
      if wantedValue~length < 3 | gotValue = "" then return .false
      if \self~safeDynamicQueryValue(gotValue) then return .false
    end
    else if wantedValue \== gotValue then return .false
  end
  return .true

::method queryParts private
  use arg query
  parts = .array~new
  remainder = query~string
  do while remainder \= ""
    amp = remainder~pos("&")
    if amp = 0 then do
      item = remainder
      remainder = ""
    end
    else do
      item = remainder~left(amp - 1)
      remainder = remainder~substr(amp + 1)
    end
    if item = "" then return .nil
    eq = item~pos("=")
    if eq <= 1 then return .nil
    key = item~left(eq - 1)
    value = item~substr(eq + 1)
    pair = .array~of(key, value)
    parts~append(pair)
  end
  return parts

::method safeDynamicQueryValue private
  use arg value
  if value = "" then return .false
  do i = 1 to value~length
    ch = value~substr(i, 1)
    if datatype(ch, "A") | datatype(ch, "N") then iterate
    if ch = "-" | ch = "_" | ch = "." | ch = "~" then iterate
    return .false
  end
  return .true

::method pathMatches private
  use arg template, actual
  t = self~segments(template)
  a = self~segments(actual)
  if t~items \= a~items then return .false
  do i = 1 to t~items
    wanted = t[i]
    got = a[i]
    if wanted~left(1) = "{" & wanted~right(1) = "}" then do
      if wanted~length < 3 | got = "" then return .false
      if \self~safeDynamicSegment(got) then return .false
    end
    else if wanted \== got then return .false
  end
  return .true


::method safeDynamicSegment private
  use arg segment
  if segment = "." | segment = ".." then return .false
  if segment~pos("\\") > 0 | segment~pos('00'x) > 0 then return .false
  lower = segment~lower
  if lower~pos("%2f") > 0 | lower~pos("%5c") > 0 | lower~pos("%00") > 0 then return .false
  if lower~pos("%2e") > 0 then return .false
  return .true

::method segments private
  use arg p
  segmentList = .array~new
  text = p
  if text~left(1) = "/" then text = text~substr(2)
  if text = "" then return segmentList
  do while text \= ""
    slash = text~pos("/")
    if slash = 0 then do
      segmentList~append(text)
      leave
    end
    segmentList~append(text~left(slash - 1))
    text = text~substr(slash + 1)
  end
  return segmentList


::class CivicAllowList subclass CivicAlchemyObject public
::attribute sealed get

::method init
  expose templates sealed
  templates = .array~new
  sealed = .false

  ignore = self~initCivicAlchemy
::method add
  expose templates sealed
  use arg scheme, host, pathTemplate, allowQuery = .false, port = "", queryTemplate = ""
  if sealed then raise syntax 93.900 additional("CivicAllowList is sealed")
  endpoint = .CivicEndpointTemplate~new(scheme, host, pathTemplate, allowQuery, port, queryTemplate)
  templates~append(endpoint)
  return endpoint

::method seal
  expose sealed
  sealed = .true
  return self

::method sealedCopy
  expose templates
  copyList = .CivicAllowList~new
  do endpoint over templates
    ignore = copyList~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
  end
  return copyList~seal

::method permits
  expose templates
  use arg url
  parts = .CivicUrlParts~parse(url)
  if parts == .nil then return .false
  do endpoint over templates
    if endpoint~matches(parts) then return .true
  end
  return .false

::method describe
  expose templates
  descriptionList = .array~new
  do endpoint over templates
    text = endpoint~scheme || "://" || endpoint~host
    if endpoint~port \= "" then text = text || ":" || endpoint~port
    text = text || endpoint~pathTemplate
    if endpoint~queryTemplate \= "" then text = text || "?" || endpoint~queryTemplate
    descriptionList~append(text)
  end
  return descriptionList

::requires "CivicAlchemy.cls"
