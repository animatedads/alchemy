from pathlib import Path
import _rexxpython_poc as _native
ROOT = Path(__file__).resolve().parent.parent
FACTORY = str(ROOT / "rexx" / "factory.rex")

class RexxProxy:
    def __init__(self, handle): self._handle = handle
    def __del__(self):
        h = getattr(self, "_handle", None)
        if h:
            try: _native.release_handle(h)
            except Exception: pass
            self._handle = None

class Animal(RexxProxy):
    @classmethod
    def new(cls, name, species, sound): return cls(_native.create_animal(FACTORY, name, species, sound))
    @property
    def name(self): return _native.send0(self._handle, "NAME")
    @property
    def species(self): return _native.send0(self._handle, "SPECIES")
    @property
    def sound(self): return _native.send0(self._handle, "SOUND")
    def describe(self): return _native.send0(self._handle, "DESCRIBE")
    def speak(self): return _native.send0(self._handle, "SPEAK")

class AnimalCollection(RexxProxy):
    @classmethod
    def new(cls): return cls(_native.create_collection(FACTORY))
    def add(self, animal): return int(_native.send1_handle(self._handle, "ADD", animal._handle))
    def __len__(self): return int(_native.send0(self._handle, "COUNT"))
    def __getitem__(self, index):
        if index < 0: index += len(self)
        if index < 0 or index >= len(self): raise IndexError(index)
        return Animal(_native.send1_index_handle(self._handle, "AT", index + 1))
    def __iter__(self):
        for i in range(len(self)): yield self[i]
