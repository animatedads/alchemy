"""Narrow Python proof-provider helpers for oorexx_maths.

This module intentionally does not define the public mathematical object model.
It translates the library's safe expression text into SymPy or mpmath interval
operations and returns evidence facts to ooRexx.
"""
import ast
import re

_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _parse(text):
    return ast.parse(text, mode="eval").body


def _sympy_from_node(node, sp, symbols, source):
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        token = ast.get_source_segment(source, node)
        if isinstance(node.value, int):
            return sp.Integer(token)
        return sp.Rational(token)
    if isinstance(node, ast.Name) and _NAME.match(node.id):
        return symbols[node.id]
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -_sympy_from_node(node.operand, sp, symbols, source)
    if isinstance(node, ast.BinOp):
        l = _sympy_from_node(node.left, sp, symbols, source)
        r = _sympy_from_node(node.right, sp, symbols, source)
        if isinstance(node.op, ast.Add): return l + r
        if isinstance(node.op, ast.Sub): return l - r
        if isinstance(node.op, ast.Mult): return l * r
        if isinstance(node.op, ast.Div): return l / r
        if isinstance(node.op, ast.Pow): return l ** r
    raise ValueError(f"unsupported maths expression node: {ast.dump(node)}")


def _names(node):
    return sorted({n.id for n in ast.walk(node) if isinstance(n, ast.Name)})


def sympy_prove_equal(expression, expected, assumptions=None):
    import sympy as sp
    assumptions = assumptions or {}
    enode = _parse(expression)
    xnode = _parse(expected)
    names = sorted(set(_names(enode)) | set(_names(xnode)))
    symbols = {}
    for name in names:
        if not _NAME.match(name):
            raise ValueError("invalid symbol name")
        facts = assumptions.get(name, {})
        kwargs = {k: bool(v) for k, v in facts.items()
                  if k in {"real", "positive", "nonnegative", "nonzero", "integer"}}
        symbols[name] = sp.Symbol(name, **kwargs)
    lhs = _sympy_from_node(enode, sp, symbols, expression)
    rhs = _sympy_from_node(xnode, sp, symbols, expected)
    diff = sp.simplify(lhs - rhs)
    # Only promote an exact symbolic reduction to zero to PROVED. SymPy's
    # Expr.equals() can use numerical probing; that is useful evidence but is
    # not treated here as a mathematical proof certificate.
    advisory = None
    if diff == 0:
        outcome = "PROVED"
    elif bool(getattr(diff, "is_number", False)):
        outcome = "DISPROVED"
    else:
        try:
            advisory = diff.equals(0)
        except Exception:
            advisory = None
        outcome = "INDETERMINATE"
    return {
        "outcome": outcome,
        "simplified_difference": str(diff),
        "sympy_version": sp.__version__,
        "method": "sympy.simplify exact-zero test",
        "equals_advisory": "None" if advisory is None else str(advisory),
    }


def _iv_from_node(node, iv, bounds, source):
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        token = ast.get_source_segment(source, node)
        return iv.mpf(token)
    if isinstance(node, ast.Name) and _NAME.match(node.id):
        lo, hi = bounds[node.id]
        return iv.mpf([str(lo), str(hi)])
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -_iv_from_node(node.operand, iv, bounds, source)
    if isinstance(node, ast.BinOp):
        l = _iv_from_node(node.left, iv, bounds, source)
        r = _iv_from_node(node.right, iv, bounds, source)
        if isinstance(node.op, ast.Add): return l + r
        if isinstance(node.op, ast.Sub): return l - r
        if isinstance(node.op, ast.Mult): return l * r
        if isinstance(node.op, ast.Div): return l / r
        if isinstance(node.op, ast.Pow): return l ** r
    raise ValueError(f"unsupported interval expression node: {ast.dump(node)}")


def mpmath_interval_eval(expression, bounds, dps=50):
    import mpmath
    from mpmath import iv
    from mpmath.libmp import to_str
    old_dps = iv.dps
    try:
        iv.dps = int(dps)
        node = _parse(expression)
        clean = {}
        for name in _names(node):
            if name not in bounds:
                raise ValueError(f"missing interval for {name}")
            clean[name] = bounds[name]
        result = _iv_from_node(node, iv, clean, expression)
        lo, hi = result._mpi_
        digits = int(dps) + 15
        lower = to_str(lo, digits)
        upper = to_str(hi, digits)
        width = to_str((result.delta)._mpi_[1], digits)
        return {
            "lower": lower,
            "upper": upper,
            "width": width,
            "enclosure": str(result),
            "mpmath_version": mpmath.__version__,
            "method": "mpmath.iv interval evaluation",
        }
    finally:
        iv.dps = old_dps


def _arb_from_node(node, arb, bounds, source):
    """Evaluate the narrow arithmetic AST using Arb balls only."""
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        token = ast.get_source_segment(source, node)
        return arb(token)
    if isinstance(node, ast.Name) and _NAME.match(node.id):
        lo, hi = bounds[node.id]
        a = arb(str(lo))
        b = arb(str(hi))
        return a.union(b)
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -_arb_from_node(node.operand, arb, bounds, source)
    if isinstance(node, ast.BinOp):
        l = _arb_from_node(node.left, arb, bounds, source)
        r = _arb_from_node(node.right, arb, bounds, source)
        if isinstance(node.op, ast.Add): return l + r
        if isinstance(node.op, ast.Sub): return l - r
        if isinstance(node.op, ast.Mult): return l * r
        if isinstance(node.op, ast.Div): return l / r
        if isinstance(node.op, ast.Pow): return l ** r
    raise ValueError(f"unsupported Arb expression node: {ast.dump(node)}")


def flint_ball_eval(expression, bounds, dps=50):
    """Evaluate an arithmetic expression with python-flint/Arb ball arithmetic.

    The serialised mid/rad/10^exp tuple is itself an enclosing decimal-ball
    certificate returned by Arb's mid_rad_10exp(); the pretty decimal string is
    display only and is not used as the proof certificate.
    """
    import flint
    from flint import arb, ctx
    old_dps = ctx.dps
    try:
        ctx.dps = int(dps)
        node = _parse(expression)
        clean = {}
        for name in _names(node):
            if name not in bounds:
                raise ValueError(f"missing ball interval for {name}")
            clean[name] = bounds[name]
        result = _arb_from_node(node, arb, clean, expression)
        mid, rad, exp = result.mid_rad_10exp(int(dps) + 10)
        return {
            "enclosure": result.str(int(dps) + 10, more=True),
            "certificate_mid": str(mid),
            "certificate_rad": str(rad),
            "certificate_exp10": str(exp),
            "relative_accuracy_bits": str(result.rel_accuracy_bits()),
            "is_exact": "1" if result.is_exact() else "0",
            "flint_version": getattr(flint, "__version__", "unknown"),
            "method": "python-flint Arb ball evaluation / mid_rad_10exp certificate",
        }
    finally:
        ctx.dps = old_dps
