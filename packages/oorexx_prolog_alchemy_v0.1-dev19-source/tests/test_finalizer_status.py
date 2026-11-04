"""Static gate for SWI query finalization; native execution remains separately required."""
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/"native/prolog_alchemy_native.cpp").read_text()
assert "int status=cut?PL_cut_query(q->qid):PL_close_query(q->qid);" in s
assert "if(status!=TRUE)" in s
assert "status==PL_S_NOT_INNER" in s
assert s.index("if(status!=TRUE)") < s.index("q->closed=true;",s.index("int status=cut?"))
assert "cleanup not confirmed" in s
print("PASS: finalizer result gates query closure and root release")
