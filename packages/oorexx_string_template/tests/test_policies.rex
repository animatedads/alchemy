ctx = .Directory~new
ctx["value"] = '<tag a="b">&''x''</tag>'
ctx["json"] = 'a"b' || "0a"x || "c\\d"
html = .StringTemplate~new("${value}")~render(ctx, .TemplateRenderPolicy~strictHtml)
call assertEq html, "&lt;tag a=&quot;b&quot;&gt;&amp;&#39;x&#39;&lt;/tag&gt;", "html escape"
json = .StringTemplate~new("${json}")~render(ctx, .TemplateRenderPolicy~strictJson)
call assertEq json, 'a\\"b\\nc\\\\d', "json escape"

permissive = .StringTemplate~new("Hello ${missing}.")~render(.Directory~new, .TemplateRenderPolicy~permissivePlain)
call assertEq permissive, "Hello ${missing}.", "keep missing"

nameCtx = .Directory~new
nameCtx["name"] = "Fred"
escaped = .StringTemplate~new("Literal $${name}; value ${name}")~render(nameCtx)
call assertEq escaped, "Literal ${name}; value Fred", "escaped placeholder"

say "PASS test_policies"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "StringTemplate.cls"
