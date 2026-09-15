def add(a: int, b: int) -> int:
    return a + b

def greet(name: str) -> str:
    return "hello " + name

def binary_len(data: bytes) -> int:
    return len(data)

def binary_echo(data: bytes) -> bytes:
    return data

class Box:
    def __init__(self, value: int):
        self.value = value
    def inc(self, amount: int) -> int:
        self.value += amount
        return self.value

def make_box(value: int) -> Box:
    return Box(value)


def describe_type(value) -> str:
    return type(value).__name__

def sum_list(values: list[int]) -> int:
    return sum(values)

def kw_format(name: str, prefix: str = "hello", *, punctuation: str = "!") -> str:
    return prefix + " " + name + punctuation

def dict_sum(values: dict[str, int]) -> int:
    return sum(values.values())

def make_dict() -> dict[str, int]:
    return {"alpha": 11, "beta": 31}

def annotated_text(value: str) -> str:
    return type(value).__name__ + ":" + value

_held_buffer = None

def buffer_type(value) -> str:
    return type(value).__name__

def buffer_len(value) -> int:
    return len(value)

def buffer_write(value, index: int, byte_value: int) -> int:
    value[index] = byte_value
    return value[index]

def buffer_bytes(value) -> bytes:
    return bytes(value)

def hold_buffer(value) -> int:
    global _held_buffer
    _held_buffer = value
    return len(value)

def release_held_buffer() -> int:
    global _held_buffer
    _held_buffer = None
    return 1

def make_bytearray() -> bytearray:
    return bytearray(b"abcdefgh")

def make_readonly_view():
    return memoryview(b"readonly")


class DTypeThing:
    def __init__(self, dtype="float32"):
        self.dtype = dtype

def make_dtype_thing(dtype: str = "float32"):
    return DTypeThing(dtype)

def module_dtype(value) -> str:
    return str(value.dtype)

def kw_dtype(*, value) -> str:
    return str(value.dtype)

def dict_dtype(values: dict) -> str:
    return str(values["value"].dtype)

def list_dtype(values: list) -> str:
    return str(values[0].dtype)


class SequenceBox:
    def __init__(self, values):
        self._values = list(values)
    def __len__(self):
        return len(self._values)
    def __getitem__(self, index):
        return self._values[index]

def make_sequence_box():
    return SequenceBox(["alpha", "beta", "gamma"])

class MappingBox:
    def __init__(self):
        self._values = {"name": "foreign", 0: "zero"}
    def __getitem__(self, key):
        return self._values[key]

def make_mapping_box():
    return MappingBox()
