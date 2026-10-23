"""Source guard only; not proof of SWI native lifecycle qualification."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]/"native/prolog_alchemy_native.cpp"
s=p.read_text()
assert "if(cut){PL_cut_query(q->qid);}else{PL_close_query(q->qid);}" in s
assert "if(cut)PL_cut_query(q->qid);PL_close_query(q->qid);" not in s
print("PASS: query cut and close are mutually exclusive in source")
