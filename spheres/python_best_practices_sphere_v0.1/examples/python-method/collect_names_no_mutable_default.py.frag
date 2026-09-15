def collect_names(records, acc=None):
    """Return the record names gathered from `records`.

    Accepts an optional `acc` collector but never bonds a mutable default.
    Each call with no `acc` gets a brand-new list, so callers never observe
    leftover state from earlier invocations.
    """
    if acc is None:
        acc = []
    for rec in records:
        acc.append(rec.get("name"))
    return acc
