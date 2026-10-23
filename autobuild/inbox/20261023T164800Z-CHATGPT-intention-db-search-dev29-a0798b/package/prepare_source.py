from pathlib import Path
import base64, shutil, zipfile
root=Path(__file__).resolve().parent
out=root/"prepared"
if out.exists(): shutil.rmtree(out)
out.mkdir()
parts=sorted(root.glob("source.b64.*"))
if not parts: raise SystemExit("missing source chunks")
archive=root/"source.rebuilt.zip"
archive.write_bytes(base64.b64decode("".join(p.read_text() for p in parts)))
with zipfile.ZipFile(archive) as z:
    for name in z.namelist():
        p=(out/name).resolve()
        if out.resolve()!=p and out.resolve() not in p.parents:
            raise SystemExit(f"unsafe archive path: {name}")
    z.extractall(out)
print(f"prepared {sum(1 for p in out.rglob('*') if p.is_file())} source files")
