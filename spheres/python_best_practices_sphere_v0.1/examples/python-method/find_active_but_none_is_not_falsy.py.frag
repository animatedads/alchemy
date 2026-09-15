def find_active(catalog, wanted_id):
    """Return the single active catalog row whose id == wanted_id.

    Returns None only when no such row exists; an existing but disabled row
    is distinguished from absence by checking is None rather than truthiness,
    because a row's own fields are never the test for its presence here.
    """
    matched = [row for row in catalog if row.get("id") == wanted_id]
    if len(matched) == 0:
        return None
    return matched[0] if matched[0].get("active") else None
