#!/usr/bin/env python3
"""Strict source edit for the existing NotNotes CLI class; not a new class authority."""
import argparse, hashlib, json, pathlib, sys
p = argparse.ArgumentParser()
p.add_argument("--source",required=True)
p.add_argument("--output",required=True)
args=p.parse_args()
s=pathlib.Path(args.source)
o=pathlib.Path(args.output)
if s.resolve()==o.resolve():
    sys.exit("REFUSED_IN_PLACE_EDIT: generate a disposable candidate, do not overwrite source")
plan=json.loads((pathlib.Path(__file__).resolve().parent.parent/"edits.json").read_text())
original=s.read_bytes()
blob=hashlib.sha1(b"blob "+str(len(original)).encode()+b"\0"+original).hexdigest()
if blob!=plan["base_git_blob_sha"]:
    sys.exit("SOURCE_BLOB_MISMATCH expected="+plan["base_git_blob_sha"]+" actual="+blob)
data=original.decode("utf-8")
for i,item in enumerate(plan["edits"]):
    count=data.count(item["before"])
    if count!=1:
        sys.exit("NON_UNIQUE_EDIT_"+str(i)+" count="+str(count))
    data=data.replace(item["before"],item["after"],1)
if "semanticCollectionRange(\"documents\", listOffset, listPageSize)" not in data:
    sys.exit("MISSING_BOUNDED_COLLECTION")
if "listSource = \"query\"" not in data or "listSource = \"view\"" not in data:
    sys.exit("MISSING_FILTER_ISOLATION")
o.parent.mkdir(parents=True,exist_ok=True)
o.write_text(data)
print("PATCH_READY edits="+str(len(plan["edits"]))+" base_blob="+blob+" output="+str(o))
