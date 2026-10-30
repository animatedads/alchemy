# Admission test cases

| Case | Gate | Expected runtime | Reason |
|---|---|---|---|
| HEXENC -> ADBINV, result passed as PREV | reject | BLOCKED, trace empty, no result | STRING cannot satisfy NUMBER |
| POWMOD(2,3,1000003) -> ADBINV(PREV,1000003) | accept | OK; 8 * inverse modulo 1000003 = 1 | Numeric kind compatible and coprime data |
| ADBINV(PREV,1000003) first | reject | BLOCKED, trace empty | No previous result exists |
| Exploratory HEXENC -> ADBINV via run | predict failure | FAILED at ADBINV | Experimental negative evidence intentionally retained |

These are assertions added to `tests/test_compose.rex`, not results from this workspace. Recheck the real ooRexx interpreter before deployment.
