def load_value(path):
    """Load one JSON value from `path`, raising clearly on I/O and format issues.

    Only OSError (and its subclasses) and ValueError are anticipated from this
    operation; they are surfaced by re-raising with context. An unknown
    programming error is deliberately NOT turned into a falsy default.
    """
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise OSError(f"could not load {path.name}: {exc}") from exc
    try:
        return json.loads(raw)
    except ValueError as exc:
        raise ValueError(f"bad JSON in {path.name}") from exc
