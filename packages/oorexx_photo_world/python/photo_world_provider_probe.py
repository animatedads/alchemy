class PhotoWorldProviderProbe:
    """Macrospace crossing probe only; this is not an image/ML implementation."""
    def __init__(self, provider_name="PhotoWorld Probe", version="0.1", lane="depth", tag="", note=""):
        self.provider_name = provider_name
        self.version = version
        self.lane = lane
        self.tag = tag
        self.note = note
        self.calls = 0

    def providerversion(self):
        return self.version

    def infer(self, source_ref):
        self.calls += 1
        return f"DEPTH-PROBE:{self.calls}:{source_ref}"

    def combine(self, a, b, c, d, e):
        return f"{a}|{b}|{c}|{d}|{e}"

    @classmethod
    def class_combine(cls, a, b, c, d, e):
        return f"{a}|{b}|{c}|{d}|{e}"

    def callcount(self):
        return self.calls
    def maths_matrix_contract(self, matrix):
        """Exercise a live ooRexx Maths object through Macrospace v0.31.6.

        Python does not own or copy the numerical payload.  It operates the
        retained ooRexx object naturally, including a positional method call
        and a chained non-string Rexx return object.
        """
        return f"{matrix.rows()}x{matrix.cols()}:{matrix.at(1, 2)}:{matrix.context().provider()}"

