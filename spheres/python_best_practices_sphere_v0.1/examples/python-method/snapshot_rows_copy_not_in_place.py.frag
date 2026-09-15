def snapshot_rows(rows):
    """Return a sorted, plain copy of `rows` so the caller's object is untouched.

    `rows` is read-only here: we do not sort in place, and the returned list is
    a new object, so mutating the result can never alter the caller's collection.
    """
    return sorted(rows, key=lambda r: r.get("seq"))
