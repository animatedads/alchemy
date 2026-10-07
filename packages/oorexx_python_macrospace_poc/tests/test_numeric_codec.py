from decimal import Decimal
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/"python"))
from numeric_codec import classify_python_value, exact_decimal_text

assert classify_python_value(True) == ("boolean", True)
assert classify_python_value(123) == ("integer", "123")
assert classify_python_value(Decimal("00123.4500")) == ("decimal", "123.4500")
assert classify_python_value("00123.4500") == ("string", "00123.4500")
assert classify_python_value(0.1)[0] == "float"
assert exact_decimal_text(10**100) == "1" + "0"*100
assert exact_decimal_text(Decimal("0.10000000000000000001")) == "0.10000000000000000001"
print("NUMERIC CODEC POLICY TEST PASS")
