"""Deterministic ForeignPython ML fixture: no sockets, no subprocesses.

v0.18 deliberately uses custom Python sequence objects for the outer envelope and
embedding vector. Foreign Runtime keeps these resident, exercising its v0.22.2
Rexx-native collection proxy (`items`, `[]`, `at`, `pythonAt`) rather than eager
list->Array conversion.
"""

class SequenceBox:
    def __init__(self, values):
        self._values = list(values)
    def __len__(self):
        return len(self._values)
    def __getitem__(self, index):
        return self._values[index]

def runtime_info():
    return SequenceBox(["ok", "fixture-speechbrain", "fixture-torch", "fixture-torchaudio"])

def speaker_embedding(media_path, model_source="", model_dir="", model_revision=""):
    embedding = SequenceBox([0.125, -0.25, 0.5])
    return SequenceBox(["ok", "FixtureML", "ECAPA-TDNN", model_source or "fixture/ecapa", model_revision or "fixture-1", 16000, "MONO", embedding, "fixture-speechbrain", "fixture-torch", "fixture-torchaudio"])

def speaker_verify(media_path_a, media_path_b, model_source="", model_dir="", model_revision="", threshold="PROVIDER_DEFAULT"):
    return SequenceBox(["ok", model_source or "fixture/ecapa", model_revision or "fixture-1", 0.8125, True, "MODEL_PROVIDER_SCORE", threshold, "fixture-speechbrain", "fixture-torch", "fixture-torchaudio"])

def sequence_probe():
    return SequenceBox(["alpha", "beta", "gamma"])
