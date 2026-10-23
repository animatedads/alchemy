/* FontManager.cls -- renderer-neutral font discovery, matching and packaging service. */

::class FontFace public
::method init
  expose id family style fullName postscriptName path index weight slant spacing scalable format source metadata
  use strict arg family, path="", style="Regular", fullName="", postscriptName="", weight=80, slant=0, spacing=0, scalable=.true, format="", source="REGISTERED", index=0
  if strip(family) == "" then raise syntax 93.900 array("Font family must not be empty")
  id = translate(strip(family)) || "|" || translate(strip(style)) || "|" || path || "|" || index
  metadata = .Directory~new
::attribute id get
::attribute family get
::attribute style get
::attribute fullName get
::attribute postscriptName get
::attribute path get
::attribute index get
::attribute weight get
::attribute slant get
::attribute spacing get
::attribute scalable get
::attribute format get
::attribute source get
::method metadata
  expose metadata
  return metadata
::method tag
  expose metadata
  use strict arg name, value
  metadata~put(value, translate(strip(name)))
  return self
::method tagValue
  expose metadata
  use strict arg name, defaultValue=""
  key=translate(strip(name))
  if metadata~hasIndex(key) then return metadata~at(key)
  return defaultValue
::method isMonospace
  expose spacing
  return spacing > 0

::class FontQuery public
::method init
  expose families purpose weight slant monospace format size language script embeddable subset web metadata
  families=.Array~new; purpose="BODY"; weight=80; slant=0; monospace=.false; format=""; size=10
  language=""; script=""; embeddable=.false; subset=.false; web=.false; metadata=.Directory~new
::method family
  expose families
  use strict arg name
  if strip(name) \== "" then families~append(strip(name))
  return self
::method families
  expose families
  return families~copy
::attribute purpose
::attribute weight
::attribute slant
::attribute monospace
::attribute format
::attribute size
::attribute language
::attribute script
::attribute embeddable
::attribute subset
::attribute web
::method tag
  expose metadata
  use strict arg name,value
  metadata~put(value,translate(strip(name)))
  return self
::method tagValue
  expose metadata
  use strict arg name, defaultValue=""
  key=translate(strip(name)); if metadata~hasIndex(key) then return metadata~at(key)
  return defaultValue

::class FontPurposeProfile public
::method init
  expose name families weight slant monospace size
  use strict arg name, families=.nil, weight=80, slant=0, monospace=.false, size=10
  if families == .nil then families=.Array~new
::attribute name get
::attribute weight get
::attribute slant get
::attribute monospace get
::attribute size get
::method families
  expose families
  return families~copy

::class FontMatch public
::method init
  expose face score reason query
  use strict arg face, score, reason="", query=.nil
::attribute face get
::attribute score get
::attribute reason get
::attribute query get

::class FontMeasurement public
::method init
  expose width ascender descender unitsPerEm provider
  use strict arg width, ascender=0, descender=0, unitsPerEm=1000, provider=""
::attribute width get
::attribute ascender get
::attribute descender get
::attribute unitsPerEm get
::attribute provider get

::class FontPackageRequest public
::method init
  expose face outputPath text characters flavor subset retainGlyphNames metadata
  use strict arg face, outputPath
  text=""; characters=""; flavor=""; subset=.true; retainGlyphNames=.false; metadata=.Directory~new
::attribute face get
::attribute outputPath get
::attribute text
::attribute characters
::attribute flavor
::attribute subset
::attribute retainGlyphNames
::method tag
  expose metadata
  use strict arg name,value
  metadata~put(value,translate(strip(name)))
  return self
::method metadata
  expose metadata
  return metadata

::class FontPackageResult public
::method init
  expose success outputPath provider message command
  use strict arg success, outputPath="", provider="", message="", command=""
::attribute success get
::attribute outputPath get
::attribute provider get
::attribute message get
::attribute command get

::class FontManager public
::method init
  expose faces providers transformers metricProviders glyphProviders purposes
  faces=.Directory~new; providers=.Array~new; transformers=.Array~new; metricProviders=.Array~new; glyphProviders=.Array~new; purposes=.Directory~new
  self~registerDefaultPurposes
::method registerDefaultPurposes private
  expose purposes
  self~registerPurpose(.FontPurposeProfile~new("BODY", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),80,0,.false,10))
  self~registerPurpose(.FontPurposeProfile~new("HEADING", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),180,0,.false,16))
  self~registerPurpose(.FontPurposeProfile~new("TABLE", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),80,0,.false,8))
  self~registerPurpose(.FontPurposeProfile~new("UI", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),80,0,.false,10))
  self~registerPurpose(.FontPurposeProfile~new("UI_COMPACT", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),80,0,.false,9))
  self~registerPurpose(.FontPurposeProfile~new("CODE", .Array~of("Noto Sans Mono","DejaVu Sans Mono","Liberation Mono"),80,0,.true,9))
  self~registerPurpose(.FontPurposeProfile~new("PRINT_BODY", .Array~of("Noto Serif","DejaVu Serif","Liberation Serif"),80,0,.false,10))
  self~registerPurpose(.FontPurposeProfile~new("WEB_BODY", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),80,0,.false,16))
  self~registerPurpose(.FontPurposeProfile~new("ACCESSIBLE_UI", .Array~of("Noto Sans","DejaVu Sans","Liberation Sans"),80,0,.false,12))
  return self
::method registerPurpose
  expose purposes
  use strict arg profile
  purposes~put(profile,translate(strip(profile~name)))
  return self
::method purpose
  expose purposes
  use strict arg name
  key=translate(strip(name)); if purposes~hasIndex(key) then return purposes~at(key)
  return .nil
::method purposes
  expose purposes
  return purposes~copy
::method registerProvider
  expose providers
  use strict arg provider
  providers~append(provider); return self
::method registerTransformer
  expose transformers
  use strict arg transformer
  transformers~append(transformer); return self
::method registerMetricsProvider
  expose metricProviders
  use strict arg provider
  metricProviders~append(provider); return self
::method registerGlyphProvider
  expose glyphProviders
  use strict arg provider
  glyphProviders~append(provider); return self
::method glyphPlan
  expose glyphProviders
  use strict arg face, text
  do provider over glyphProviders
    if provider~supports(face) then return provider~plan(face,text)
  end
  raise syntax 93.900 array("No registered glyph provider supports face: " || face~family)
::method measure
  expose metricProviders
  use strict arg face, text, size
  do provider over metricProviders
    if provider~supports(face) then return provider~measure(face,text,size)
  end
  /* Fallback is explicitly approximate and exists only so callers can keep a
     renderer-neutral code path when no metric provider is installed. */
  return .FontMeasurement~new(length(text)*size*0.52,size*0.8,-size*0.2,1000,"APPROXIMATE")
::method registerFace
  expose faces
  use strict arg face
  faces~put(face,face~id); return face
::method faces
  expose faces
  a=.Array~new; s=faces~supplier
  do while s~available; a~append(s~item); s~next; end
  return a
::method discover
  expose providers
  use arg refresh=.false
  count=0
  do provider over providers
    found=provider~discover(refresh)
    do face over found
      self~registerFace(face); count=count+1
    end
  end
  return count
::method queryForPurpose
  use strict arg purposeName
  p=self~purpose(purposeName)
  if p == .nil then raise syntax 93.900 array("Unknown font purpose:" purposeName)
  q=.FontQuery~new; q~purpose=p~name; q~weight=p~weight; q~slant=p~slant; q~monospace=p~monospace; q~size=p~size
  do family over p~families; q~family(family); end
  return q
::method findForPurpose
  use strict arg purposeName
  return self~find(self~queryForPurpose(purposeName))
::method find
  expose faces providers
  use strict arg query
  best=.nil
  /* Providers can perform native matching without a full scan. */
  do provider over providers
    candidate=provider~find(query)
    if candidate \== .nil then do
      match=self~scoreFace(candidate,query)
      if best == .nil then best=match
      else if match~score > best~score then best=match
    end
  end
  s=faces~supplier
  do while s~available
    candidate=s~item; match=self~scoreFace(candidate,query)
    if best == .nil then best=match
    else if match~score > best~score then best=match
    s~next
  end
  return best
::method scoreFace private
  use strict arg face, query
  score=0; reason=""
  families=query~families
  do i=1 to families~items
    wanted=translate(strip(families[i])); actual=translate(strip(face~family))
    if wanted == actual then do; score=score + 1200 - (i*10); reason=reason||" family-exact"; leave; end
    if pos(wanted,actual)>0 | pos(actual,wanted)>0 then do; score=score + 500 - (i*5); reason=reason||" family-near"; leave; end
  end
  delta=abs(face~weight-query~weight); score=score + max(0,200-delta)
  if face~slant == query~slant then score=score+120
  if query~monospace then do
    if face~isMonospace then score=score+350; else score=score-700
  end
  if query~format \== "" then do
    if translate(face~format)==translate(query~format) then score=score+100; else score=score-100
  end
  if query~embeddable then do
    emb=translate(face~tagValue("EMBEDDING","UNKNOWN"))
    if emb == "RESTRICTED" then score=score-5000
  end
  return .FontMatch~new(face,score,strip(reason),query)
::method package
  expose transformers
  use strict arg request
  if request~face == .nil then return .FontPackageResult~new(.false,"","","No font face supplied")
  emb=translate(request~face~tagValue("EMBEDDING","UNKNOWN"))
  if emb == "RESTRICTED" then return .FontPackageResult~new(.false,"","","Font embedding is restricted by face metadata")
  do transformer over transformers
    if transformer~supports(request) then return transformer~transform(request)
  end
  return .FontPackageResult~new(.false,"","","No registered transformer supports this packaging request")
::method cssFamily
  use strict arg face
  fam=changestr('"',face~family,'\\"')
  return '"'||fam||'"'
::method cssFaceRule
  use strict arg face, url, formatHint=""
  fmt=formatHint; if fmt=="" then fmt=translate(face~format)
  hint=""; if fmt \== "" then hint=" format('"||lower(fmt)||"')"
  return "@font-face { font-family: "||self~cssFamily(face)||"; src: url('"||url||"')"||hint||"; font-weight: "||face~weight||"; font-style: "||self~cssStyle(face)||"; }"
::method cssStyle private
  use strict arg face
  if face~slant > 0 then return "italic"
  return "normal"

/* Neutral glyph inventory used by renderers that need explicit glyph identity. */
::class FontGlyph public
::method init
  expose utf8Bytes unicodeHex codepoint glyphId advance
  use strict arg utf8Bytes, unicodeHex, codepoint, glyphId, advance
::attribute utf8Bytes get
::attribute unicodeHex get
::attribute codepoint get
::attribute glyphId get
::attribute advance get

::class FontGlyphPlan public
::method init
  expose face unitsPerEm ascender descender xMin yMin xMax yMax postscriptName glyphs byBytes provider
  use strict arg face, unitsPerEm, ascender, descender, xMin, yMin, xMax, yMax, postscriptName="", provider=""
  glyphs=.Array~new; byBytes=.Directory~new
::attribute face get
::attribute unitsPerEm get
::attribute ascender get
::attribute descender get
::attribute xMin get
::attribute yMin get
::attribute xMax get
::attribute yMax get
::attribute postscriptName get
::attribute provider get
::method addGlyph
  expose glyphs byBytes
  use strict arg glyph
  glyphs~append(glyph); byBytes~put(glyph,glyph~utf8Bytes)
  return self
::method glyphs
  expose glyphs
  return glyphs~copy
::method glyphForBytes
  expose byBytes
  use strict arg bytes
  if byBytes~hasIndex(bytes) then return byBytes~at(bytes)
  return .nil
::method measure
  expose byBytes unitsPerEm ascender descender provider
  use strict arg text,size
  total=0; p=1
  do while p<=length(text)
    first=c2d(substr(text,p,1)); n=1
    if first>=240 then n=4
    else if first>=224 then n=3
    else if first>=192 then n=2
    bytes=substr(text,p,n)
    if byBytes~hasIndex(bytes) then total=total+byBytes~at(bytes)~advance
    p=p+n
  end
  scale=size/unitsPerEm
  return .FontMeasurement~new(total*scale,ascender*scale,descender*scale,unitsPerEm,provider)
