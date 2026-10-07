class VirtualCounter:
    def __init__(self, name, value=0, *labels):
        self.name = name
        self.value = int(value)
        self.labels = tuple(labels)

    def bump(self, amount=1):
        self.value += int(amount)
        return self.value

    def describe(self):
        suffix = ",".join(self.labels)
        return f"{self.name}:{self.value}" + (f":[{suffix}]" if suffix else "")

    def combine(self, *parts):
        return "|".join(str(x) for x in parts)

    @classmethod
    def family(cls):
        return "PYTHON-VIRTUAL-CLASS"

    @classmethod
    def class_combine(cls, *parts):
        return "|".join(str(x) for x in parts)

# v0.31.3 identity-bearing argument/return qualification helpers.
class IdentityBox:
    def __init__(self, value): self.value = value
    def same(self, other): return self is other
    def same_pair(self, left, right): return left is right
    def accepts_type(self, cls): return cls is IdentityBox
    def my_type(self): return type(self)
    @classmethod
    def class_same(cls, other): return other is cls

class RexxPeerHolder:
    def __init__(self, peer):
        self.peer = peer
    def ask(self):
        return self.peer.send("DESCRIBE")
    def same(self, peer):
        return self.peer is peer

class NaturalRexxPeerHolder:
    def __init__(self, peer):
        self.peer = peer
    def ask(self):
        return self.peer.describe()

class NaturalRexxArgsHolder:
    def __init__(self, peer):
        self.peer = peer

    def combine(self):
        return self.peer.combine("left", 7, "")

    def child(self):
        return self.peer.child()

    def child_name(self):
        return self.child().describe()

    def same_child(self):
        child = self.child()
        return self.peer.same(child)


class RexxExceptionProbe:
    def __init__(self, peer):
        self.peer = peer

    def inspect_failure(self):
        try:
            self.peer.explode()
        except Exception as exc:
            return "%s|%s|%s|%s" % (type(exc).__name__, getattr(exc, "code", ""), getattr(exc, "condition_name", ""), getattr(exc, "rc", ""))
        return "NO-FAILURE"
