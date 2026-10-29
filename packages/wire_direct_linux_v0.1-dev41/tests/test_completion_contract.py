"""Executable headless qualification for Wire's completion boundary.
This models the public contract without requiring a GUI or a language engine.
The fake language providers intentionally expose different spellings and an
authority-restricted surface over the same live event object.
"""
class Event:
    def __init__(self):
        self.source = "messageList"
        self.trigger = "SelectionChanged"
        self._secret = "renderer/native authority"
        self.getter_calls = 0
    @property
    def dangerous(self):
        self.getter_calls += 1
        raise AssertionError("completion executed a getter")

class Projection:
    def __init__(self, allowed): self.allowed = tuple(allowed)

class Provider:
    def __init__(self, projection, syntax):
        self.projection, self.syntax = projection, syntax
    def complete(self, request):
        # Metadata only: never getattr()/dir()/execute against the live object.
        assert request["variables"]["event"] is event
        return [self.syntax(x) for x in self.projection.allowed]

class CompletionService:
    def __init__(self): self.providers = {}
    def register(self, language, provider): self.providers[language] = provider
    def complete(self, language, text, cursor, variables):
        p = self.providers.get(language)
        return [] if p is None else p.complete({"language":language,"source":text,"cursor":cursor,"variables":variables})

event = Event()
svc = CompletionService()
# Same live object; different language-native presentation.
svc.register("rexx", Provider(Projection(["source","trigger"]), lambda x: x + "~"))
svc.register("javascript", Provider(Projection(["source","trigger"]), lambda x: x))
# Restricted JS projection deliberately withholds trigger and all native/secret state.
restricted = CompletionService()
restricted.register("javascript", Provider(Projection(["source"]), lambda x: x))

r = svc.complete("rexx", "event~", 6, {"event":event})
j = svc.complete("javascript", "event.", 6, {"event":event})
assert r == ["source~","trigger~"]
assert j == ["source","trigger"]
assert restricted.complete("javascript", "event.", 6, {"event":event}) == ["source"]
assert event.getter_calls == 0
assert "_secret" not in j and "dangerous" not in j
# Caret/language containment: provider switch is explicit and stateless.
assert svc.complete("javascript", "event.", 6, {"event":event}) == j
assert svc.complete("rexx", "event~", 6, {"event":event}) == r
assert svc.complete("prolog", "", 0, {"event":event}) == []
print("PASS headless completion: language containment + same live identity + projection authority + no getter execution")
