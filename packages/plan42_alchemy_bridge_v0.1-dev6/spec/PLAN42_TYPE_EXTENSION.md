# Plan42 Type Extension

Plan42 specs are language-independent but target languages have type systems.
Without type information, generators must guess:
- Is `"words"` in an args list a variable named words, or the string "words"?
- Should `line_n` be declared as int, str, or untyped?
- How should a value be coerced for a typed parameter?

This extension adds lightweight type annotation to Plan42 nodes.

## New ops

### `var` — explicit variable reference
Previously bare strings in args were treated as variable references.
Using `var` makes intent unambiguous:

```json
{"op": "var", "name": "handles"}
{"op": "var", "name": "lang", "type": "str"}
```

Backends: Python `handles`, OORexx `handles`, Java `handles`

### `cast` — type coercion
```json
{"op": "cast", "expr": {"op":"var","name":"line_n"}, "to": "str"}
{"op": "cast", "expr": {"op":"var","name":"count"},  "to": "int"}
{"op": "cast", "expr": {"op":"var","name":"data"},   "to": "dict"}
```

Backend rendering:

| Plan42 `to` | Python        | OORexx          | Java                    |
|-------------|---------------|-----------------|-------------------------|
| `str`       | `str(x)`      | `''||x`         | `String.valueOf(x)`     |
| `int`       | `int(x)`      | `x+0`           | `Integer.parseInt(x)`   |
| `float`     | `float(x)`    | `x+0.0`         | `Double.parseDouble(x)` |
| `bool`      | `bool(x)`     | `x == 1`        | `Boolean.parseBoolean(x)` |
| `list`      | `list(x)`     | `.Array~new`    | `new ArrayList<>(x)`    |
| `dict`      | `dict(x)`     | `.Directory~new`| `new HashMap<>(x)`      |

### `type` field on `literal`
Disambiguates string literals from variable references when bare strings
are passed in args:

```json
{"op": "literal", "value": "words", "type": "str"}
{"op": "literal", "value": 0,       "type": "int"}
{"op": "literal", "value": true,    "type": "bool"}
```

### `type` field on `declare` / `assign`
Gives backends enough information to emit typed declarations:

```json
{"op": "declare", "name": "handles", "type": "dict",  "value": ...}
{"op": "declare", "name": "line_n",  "type": "int",   "value": {"op":"literal","value":0}}
{"op": "declare", "name": "written", "type": "int",   "value": {"op":"literal","value":0}}
```

Backend rendering of typed declare:

| type   | Python              | OORexx                        |
|--------|---------------------|-------------------------------|
| `int`  | `line_n = 0`        | `line_n = 0`                  |
| `str`  | `word = ""`         | `word = ''`                   |
| `dict` | `handles = {}`      | `handles = .Directory~new`    |
| `list` | `items = []`        | `items = .Array~new`          |

### `type` field on `routine` params
```json
{"op": "routine", "name": "extract_all_languages",
 "params": ["input_path", "output_dir", "target_langs", "progress_interval"],
 "param_types": {"input_path":"str", "output_dir":"str",
                 "target_langs":"list", "progress_interval":"int"}}
```

## Backward compatibility
All type fields are optional. Generators without type support ignore them
and produce their current output. Type-aware backends use them to produce
cleaner, safer code.

## Why not a full type system?
Plan42 is a transport format, not a programming language. The type extension
is intentionally minimal: enough to disambiguate literals from variables,
enough to guide cast generation, enough for typed language backends. Full
generic types (`List<String>`, `Dict[str, int]`) are left to backend-specific
impl nodes.
