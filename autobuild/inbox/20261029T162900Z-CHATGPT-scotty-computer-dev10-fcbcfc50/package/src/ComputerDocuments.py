"""Bounded read-only document inspection; ZIP members are never extracted."""
from pathlib import Path, PurePosixPath
import re
import shlex
import stat
import zipfile

EXTENSIONS = {'.md', '.txt', '.rst', '.json', '.yaml', '.yml', '.toml',
              '.xml', '.csv', '.tsv', '.html', '.htm', '.log', '.ini', '.cfg',
              '.py', '.sh', '.rex', '.cls'}
MAX_DOCUMENT_BYTES = 1024 * 1024
MAX_ARCHIVE_BYTES = 256 * 1024 * 1024
MAX_ARCHIVE_ENTRIES = 10000


def _path(name, error):
    p = Path(name).expanduser()
    if not p.is_absolute() or p.is_symlink() or not p.is_file():
        raise error('Document/archive must be an absolute existing non-symlink regular file', 4)
    return p


def _zip(path, error):
    if path.suffix.casefold() != '.zip' or path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise error('ZIP archive is unsupported or above 256 MiB limit', 4)
    try:
        archive = zipfile.ZipFile(path)
        if len(archive.infolist()) > MAX_ARCHIVE_ENTRIES:
            archive.close()
            raise error('ZIP member count exceeds 10000', 4)
        return archive
    except (OSError, zipfile.BadZipFile) as exc:
        raise error('Unreadable ZIP archive: ' + str(exc), 1) from exc


def _safe_member(entry):
    name = entry.filename
    parts = PurePosixPath(name).parts
    mode = entry.external_attr >> 16
    return (not entry.is_dir() and not entry.flag_bits & 1 and
            len(name) <= 1024 and not name.startswith('/') and
            not any(p in {'.', '..'} for p in parts) and '\\' not in name and
            not stat.S_ISLNK(mode) and Path(name).suffix.casefold() in EXTENSIONS)


def _render(label, data):
    if b'\x00' in data:
        raise ValueError('Binary document refused')
    try:
        content = data.decode('utf-8')
    except UnicodeDecodeError as exc:
        raise ValueError('Only valid UTF-8 text documents are supported') from exc
    print(label)
    print(content, end='' if content.endswith('\n') else '\n')
    return 0


def execute(text, error):
    try:
        words = shlex.split(text)
    except ValueError as exc:
        raise error('Document command quote error: ' + str(exc), 2) from exc
    low = [v.casefold() for v in words]
    if len(words) == 3 and low[:2] == ['read', 'document']:
        path = _path(words[2], error)
        if path.suffix.casefold() not in EXTENSIONS or path.stat().st_size > MAX_DOCUMENT_BYTES:
            raise error('Document type unsupported or above 1 MiB limit', 4)
        try:
            return _render('DOCUMENT path=' + str(path) + ' bytes=' + str(path.stat().st_size), path.read_bytes())
        except ValueError as exc:
            raise error(str(exc), 4) from exc
    if len(words) == 4 and low[:3] == ['list', 'documents', 'in']:
        archive_path = _path(words[3], error)
        with _zip(archive_path, error) as zf:
            docs = [m for m in zf.infolist() if _safe_member(m) and m.file_size <= MAX_DOCUMENT_BYTES]
        print(f'DOCUMENTS archive={archive_path} count={len(docs)} extracted=false')
        for m in docs:
            print(f'{m.filename}    {m.file_size} bytes')
        return 0
    if len(words) == 5 and low[:2] == ['read', 'document'] and low[3] == 'in':
        member, path = words[2], _path(words[4], error)
        with _zip(path, error) as zf:
            matches = [m for m in zf.infolist() if m.filename == member]
            if len(matches) != 1:
                raise error('ZIP member missing or ambiguous: ' + member, 1 if not matches else 4)
            entry = matches[0]
            if not _safe_member(entry) or entry.file_size > MAX_DOCUMENT_BYTES:
                raise error('ZIP member unsafe, encrypted, or above document byte limit', 4)
            try:
                with zf.open(entry, 'r') as stream:
                    data = stream.read(MAX_DOCUMENT_BYTES + 1)
                if len(data) > MAX_DOCUMENT_BYTES:
                    raise error('Decompressed member exceeds 1 MiB limit', 4)
                return _render(f'DOCUMENT archive={path} member={member} bytes={len(data)} extracted=false', data)
            except (RuntimeError, zipfile.BadZipFile, OSError, ValueError) as exc:
                raise error('Unable to read member safely: ' + str(exc), 4) from exc
    raise error('Use: read document ABSOLUTE_FILE | list documents in ZIP | read document MEMBER in ZIP', 2)
