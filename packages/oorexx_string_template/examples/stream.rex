context = .Directory~new
context["name"] = "Fred"
context["count"] = 7
template = .StringTemplate~new("Hello ${name}; count=${count}." || "0a"x)
output = .Stream~new("template-output.txt")
output~open("write replace")
written = template~renderTo(output, context)
output~close
say "wrote" written "characters"
::requires "StringTemplate.cls"
