r = .LlmPaCliParser~parse('-remember {"ED209E", "Google Server, have to restart it with gcloud"}')
call must r~ok, "remember parse"
call must r~value["command"] = "remember", "remember command"
call must r~value["arg1"] = "ED209E", "remember key"
call must r~value["arg2"] = "Google Server, have to restart it with gcloud", "remember value"
r = .LlmPaCliParser~parse('-remember "for ssh we have a configured script ./sshnode.sh"')
call must r~ok, "free-form remember parse"
call must r~value["command"] = "remember", "free-form remember command"
call must r~value["arg1"] = "for ssh we have a configured script ./sshnode.sh", "free-form remember fact"
call must r~value["arg2"] = "", "free-form remember empty explicit value"
r = .LlmPaCliParser~parse('-remind {"ed209e crash"}')
call must r~ok, "remind parse"
call must r~value["arg1"] = "ed209e crash", "remind text"
r = .LlmPaCliParser~parse('remind "IN 10 minutes check ed209 finished build"')
call must r~ok, "remind after parse"
call must r~value["command"] = "remind", "natural remind delegated to Gemma"
call must r~value["arg1"] = "IN 10 minutes check ed209 finished build", "remind after text"
r = .LlmPaCliParser~parse('-remind {10 secdonds time, what is ed209e}')
call must r~ok, "natural typo reminder parse"
call must r~value["command"] = "remind", "natural typo reminder delegated to Gemma"
call must r~value["arg1"] = "10 secdonds time, what is ed209e", "natural typo reminder text preserved"
r = .LlmPaCliParser~parse('-remind-after "IN 1 hour inspect ED209E"')
call must r~ok, "explicit remind-after parse"
call must r~value["command"] = "remind_after", "explicit remind-after command"
r = .LlmPaCliParser~parse('-gopher "queue fabric authority"')
call must r~ok, "gopher parse"
call must r~value["command"] = "gopher", "gopher command"
call must r~value["arg1"] = "queue fabric authority", "gopher query"
r = .LlmPaCliParser~parse('-calendar')
call must r~ok, "calendar parse"
call must r~value["command"] = "calendar", "calendar command"
r = .LlmPaCliParser~parse('read-calendar')
call must r~ok, "read-calendar parse"
call must r~value["command"] = "calendar", "read-calendar command"
r = .LlmPaCliParser~parse('package stage /tmp/example.zip')
call must r~ok, "package stage parse"
call must r~value["command"] = "package_stage", "package stage command"
r = .LlmPaCliParser~parse('package release-analyse /tmp/work tree')
call must r~ok, "package release-analyse parse"
call must r~value["command"] = "package_release_analyse", "package release-analyse command"
call must r~value["arg1"] = "/tmp/work tree", "package release-analyse path"
r = .LlmPaCliParser~parse('package release /tmp/work tree')
call must r~ok, "package release parse"
call must r~value["command"] = "package_release", "package release command"
call must r~value["arg1"] = "/tmp/work tree", "package release path"
r = .LlmPaCliParser~parse('abilities package')
call must r~ok, "abilities parse"
call must r~value["command"] = "ability_catalogue", "abilities command"
call must r~value["arg1"] = "package", "abilities filter"
r = .LlmPaCliParser~parse('ability plan.current {}')
call must r~ok, "ability invoke parse"
call must r~value["command"] = "ability_invoke", "ability invoke command"
call must r~value["arg1"] = "plan.current", "ability invoke id"
call must r~value["arg2"] = "{}", "ability invoke json"
r = .LlmPaCliParser~parse('plan current')
call must r~ok, "plan current parse"
call must r~value["command"] = "ability_invoke", "plan current ability command"
call must r~value["arg1"] = "plan.current", "plan current ability id"
r = .LlmPaCliParser~parse('continuity current')
call must r~ok, "continuity current parse"
call must r~value["command"] = "ability_invoke", "continuity current ability command"
call must r~value["arg1"] = "continuity.current", "continuity current ability id"
r = .LlmPaCliParser~parse('-next')
call must r~ok, "next parse"
call must r~value["command"] = "_next", "next command"
say "PASS test_cli_parser"
exit 0
must: procedure
 use arg ok,label
 if \ok then do; say "FAIL" label; exit 1; end
return
::requires "LlmPaCommandClient.cls"
