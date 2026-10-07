context = .Directory~new
context["name"] = "Fred"
context["count"] = 7
template = .StringTemplate~new("Hello ${name}. You have ${count} messages.")
say template~render(context)
say "requires:" template~variables~toString("l", ", ")
::requires "StringTemplate.cls"
