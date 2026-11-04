#!/usr/bin/env python3
"""Preserve typed native failure classification; never forward untrusted bytes."""
import pathlib
import sys
CODES = frozenset((
    "RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE",
    "RTO2_MI_UNAUTHENTICATED_REJECTION",
    "RTO2_MI_RESPONSE_NOT_QFXTP",
    "XTP_RESPONSE_AUTH_FAILED",
    "XTP_RESPONSE_BINDING_FAILED",
    "XTP_RESPONSE_INVALID",
    "XTP_REQUEST_FAILED",
    "RTO2_REMOTE_REJECT",
    "RTO2_WRONG_RESPONSE",
    "RTO2_RESULT_IDENTITY_MISMATCH",
    "RTO2_RESULT_NOT_COMMITTED",
))
def classify(contents):
    for line in contents.splitlines():
        word = line.split(" ", 1)[0]
        if word in CODES:
            return word
    return "NATIVE_EXECUTION_FAILURE"
if __name__ == "__main__":
    if len(sys.argv) != 2:sys.exit(64)
    try:
        with pathlib.Path(sys.argv[1]).open("rb") as fd:data=fd.read(65536)
        print(classify(data.decode("utf-8", "replace")))
    except OSError:
        print("NATIVE_EXECUTION_FAILURE")
