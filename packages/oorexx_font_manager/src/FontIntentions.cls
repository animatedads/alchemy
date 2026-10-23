/* FontIntentions.cls -- Intention Service registration profile for font operations. */
::class FontIntentions public
::method install class
  use strict arg service
  if service~bucket("FONT") == .nil then service~registerBucket("FONT", .IntentionBucketPolicy~new("FLEXIBLE",60,12,.false,.false))
  service~registerProvider(.FontIntentionProvider~new)

  r=service~register("find font", "FONT.FIND", "FONT")
  r~alias("find a font")~alias("choose font")~alias("select font")~alias("font for body text")~alias("font for headings")~alias("font for code")
  r~semantics("find choose select resolve", "font typeface body heading code ui web print")~tag("SPHERE","FONT")~tag("OPERATION","FIND")

  r=service~register("list fonts", "FONT.LIST", "FONT")
  r~alias("show fonts")~alias("available fonts")~alias("what fonts are installed")
  r~semantics("list show enumerate discover", "fonts typefaces")~tag("SPHERE","FONT")~tag("OPERATION","LIST")

  r=service~register("register font", "FONT.REGISTER", "FONT")
  r~alias("add font")~alias("register typeface")
  r~semantics("register add", "font typeface")~tag("SPHERE","FONT")~tag("OPERATION","REGISTER")

  r=service~register("package font", "FONT.PACKAGE", "FONT")
  r~alias("package font for web")~alias("make web font")~alias("prepare font for application")
  r~semantics("package prepare transform build", "font webfont application subset")~tag("SPHERE","FONT")~tag("OPERATION","PACKAGE")

  r=service~register("package font for web", "FONT.PACKAGE_WEB", "FONT")
  r~alias("make web font")~alias("prepare web font")
  r~semantics("package prepare transform build", "web font webfont woff woff2 subset")~tag("SPHERE","FONT")~tag("OPERATION","PACKAGE_WEB")

  r=service~register("subset font", "FONT.SUBSET", "FONT")
  r~alias("subset a font")~alias("keep required glyphs")~alias("make smaller font")
  r~semantics("subset reduce trim", "font glyphs characters")~tag("SPHERE","FONT")~tag("OPERATION","SUBSET")

  r=service~register("measure text", "FONT.MEASURE", "FONT")
  r~alias("size text")~alias("measure font text")~alias("how wide is this text")
  r~semantics("measure size", "text font glyphs width")~tag("SPHERE","FONT")~tag("OPERATION","MEASURE")
  return service


::class FontIntentionProvider public
::method name
  return "FONT"
::method propose
  use strict arg service, text
  u=translate(space(text)); out=.Array~new
  id=""; meaning=""
  if pos("PACKAGE FONT FOR WEB",u)>0 | pos("WEB FONT",u)>0 | pos("WEBFONT",u)>0 then do; id="PACKAGE_FONT_FOR_WEB"; meaning="package font for web"; end
  else if pos("SUBSET",u)>0 & pos("FONT",u)>0 then do; id="SUBSET_FONT"; meaning="subset font"; end
  else if pos("MEASURE",u)>0 & pos("TEXT",u)>0 then do; id="MEASURE_TEXT"; meaning="measure text"; end
  else if (pos("LIST",u)>0 | pos("SHOW",u)>0 | pos("AVAILABLE",u)>0) & pos("FONT",u)>0 then do; id="LIST_FONTS"; meaning="list fonts"; end
  else if (pos("REGISTER",u)>0 | pos("ADD FONT",u)>0) & pos("FONT",u)>0 then do; id="REGISTER_FONT"; meaning="register font"; end
  else if (pos("FIND",u)>0 | pos("CHOOSE",u)>0 | pos("SELECT",u)>0 | pos("FONT FOR",u)>0) & pos("FONT",u)>0 then do; id="FIND_FONT"; meaning="find font"; end
  else if pos("PACKAGE",u)>0 & pos("FONT",u)>0 then do; id="PACKAGE_FONT"; meaning="package font"; end
  if id=="" then return out
  p=.IntentionProposal~new(id,130,self~name,.true,meaning)
  p~putSlot("MEANING",meaning,.true)
  out~append(p)
  return out

::requires "IntentionService.cls"
