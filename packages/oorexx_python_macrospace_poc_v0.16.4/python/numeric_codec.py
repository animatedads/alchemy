"""Conservative candidate numeric policy for the bridge."""
from decimal import Decimal

def classify_python_value(value):
    if value is None:
        return ("nil", None)
    if isinstance(value, bool):
        return ("boolean", value)
    if isinstance(value, int):
        return ("integer", str(value))
    if isinstance(value, Decimal):
        return ("decimal", str(value))
    if isinstance(value, float):
        return ("float", value.hex())
    if isinstance(value, str):
        return ("string", value)
    return ("object", value)

def exact_decimal_text(value):
    kind, payload = classify_python_value(value)
    if kind in ("integer", "decimal"):
        return payload
    raise TypeError(f"{kind} is not an exact decimal bridge value")
