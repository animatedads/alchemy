# Plan42 Node Specification
# Language-Independent Program Representation Format

Version: 1.1
Status: Draft

This document specifies all valid node types in the Plan42 intermediate
representation. Each node is a JSON object with an "op" field that identifies
its type. Nodes form a tree: routines contain statement bodies, expressions
contain sub-expressions.

Backends (Python3, OORexx, Rust, Bash, etc.) render each node to idiomatic
target-language code. The spec is language-neutral; backends handle syntax.

---

## 1. TOP-LEVEL NODES (spec.nodes array)

### 1.1 CONST
Declares a module-level constant.

```json
{ "op": "const",
  "name": "SUPPORTED_LANGS",
  "value": {"op":"literal","value":["en","fr","de"]},
  "type": "list" }
```

Fields: name (str), value (expr), type? (type-hint)
Backends: Python `NAME = value`, OORexx `NAME = value`, Rust `const NAME: Type = value;`

### 1.2 IMPL
Declares a named implementation block. Not emitted directly; resolved when
referenced by IMPL_USE. Each language key in `implementations` contains the
rendering for that backend.

```json
{ "op": "impl",
  "name": "wik.extract_topics",
  "abstract": "Extract topic tags from a Wiktextract entry.",
  "params": ["entry"],
  "param_types": {"entry": "dict"},
  "return_type": "list",
  "implementations": {
    "python3":  {"type":"inline","inline":"_extract_topics({entry})"},
    "rust":     {"type":"inline","inline":"p42_extract_topics(&{entry})"},
    "generic":  {"type":"stub"}
  } }
```

Fields: name, abstract?, params?, param_types?, return_type?, implementations

### 1.3 ROUTINE
Declares a callable function/procedure.

```json
{ "op": "routine",
  "name": "extract_all_languages",
  "params": ["input_path","output_dir","target_langs","progress_interval"],
  "param_types": {"input_path":"str","output_dir":"str",
                  "target_langs":"list","progress_interval":"int"},
  "return_type": "void",
  "body": [ ...statements... ] }
```

Fields: name, params?, param_types?, return_type?, body (stmt array)

---

## 2. STATEMENT NODES (routine body, if/for/while body)

### 2.1 DECLARE
First assignment to a variable (introduces it to scope).

```json
{ "op": "declare", "name": "line_n", "type": "int",
  "value": {"op":"literal","value":0} }
```

Backends: Python `name = value`, Rust `let mut name: Type = value;`

### 2.2 ASSIGN
Re-assignment to an existing variable.

```json
{ "op": "assign", "name": "line_n",
  "value": {"op":"add","left":"line_n","right":{"op":"literal","value":1}} }
```

### 2.3 RETURN
Return from a routine, optionally with a value.

```json
{ "op": "return", "expr": {"op":"var","name":"buckets"} }
{ "op": "return" }
```

### 2.4 OUTPUT
Emit a value to stdout.

```json
{ "op": "output", "expr": {"op":"var","name":"message"} }
```

Backends: Python `print(expr)`, OORexx `say expr`, Rust `println!("{}", expr)`

### 2.5 IMPL_USE
Call a named implementation and optionally capture the result.

```json
{ "op": "impl_use",
  "name": "preferred.file.stream_lines",
  "args": ["input_path"],
  "result": "line_iter" }
```

`result` is omitted or null for void calls.

### 2.6 IF
Conditional branch. ELSE and ELIF not yet in spec; use nested IF.

```json
{ "op": "if",
  "cond": {"op":"eq","left":"entry","right":{"op":"nil"}},
  "body": [{"op":"continue"}] }
```

Fields: cond (expr), body (stmt array)
Planned: else_body, elif (array of {cond, body})

### 2.7 FOR_EACH
Iterate over a collection or iterator expression.

```json
{ "op": "for_each",
  "var": "raw_line",
  "in": {"op":"impl_use","name":"preferred.file.stream_lines",
         "args":["input_path"]},
  "body": [ ...statements... ] }
```

### 2.8 FOR_RANGE  [PLANNED]
Numeric range loop.

```json
{ "op": "for_range",
  "var": "i",
  "from": {"op":"literal","value":0},
  "to":   {"op":"var","name":"count"},
  "step": {"op":"literal","value":1},
  "body": [ ...statements... ] }
```

Backends: Python `for i in range(from, to, step)`, Rust `for i in from..to`

### 2.9 WHILE  [PLANNED]
Loop while condition holds.

```json
{ "op": "while",
  "cond": {"op":"var","name":"running"},
  "body": [ ...statements... ] }
```

Backends: Python `while cond:`, Rust `while cond { }`, OORexx `do while cond`

### 2.10 TRY  [PLANNED]
Exception / error handling block.

```json
{ "op": "try",
  "body":    [ ...statements... ],
  "catches": [
    { "type": "IOError", "var": "e",
      "body": [{"op":"output","expr":"e"}] }
  ],
  "finally": [ ...statements... ] }
```

Backends: Python `try/except/finally`,
          Rust `match result { Ok(v) => ..., Err(e) => ... }` (via Result),
          OORexx `signal on / condition('O')`

### 2.11 RAISE  [PLANNED]
Raise / throw an error.

```json
{ "op": "raise",
  "type": "ValueError",
  "message": {"op":"literal","value":"bad input"} }
```

### 2.12 MATCH  [PLANNED]
Pattern match / select-when.

```json
{ "op": "match",
  "expr": {"op":"var","name":"op_code"},
  "arms": [
    {"pattern":"LITERAL", "body":[...]},
    {"pattern":"VAR",     "body":[...]},
    {"pattern":null,      "body":[...]}
  ] }
```

null pattern = default/otherwise arm.
Backends: Python `match/case` (3.10+) or if/elif chain,
          Rust `match`, OORexx `select/when/otherwise`

### 2.13 CONTINUE / BREAK
Loop control.

```json
{ "op": "continue" }
{ "op": "break" }
```

---

## 3. EXPRESSION NODES

Expressions appear in: value/expr/cond fields of statements, and args arrays.
Bare strings in args positions are treated as variable references (VAR).

### 3.1 LITERAL
A constant value.

```json
{"op":"literal","value":42}
{"op":"literal","value":"hello","type":"str"}
{"op":"literal","value":["en","fr"],"type":"list"}
{"op":"literal","value":{"a":1},"type":"dict"}
{"op":"literal","value":true,"type":"bool"}
```

type field disambiguates when value could be misread (e.g. "words" as var vs string).

### 3.2 NIL
The null/None/nil value.

```json
{"op":"nil"}
```

### 3.3 VAR
Explicit variable reference (preferred over bare string in args).

```json
{"op":"var","name":"handles"}
{"op":"var","name":"lang","type":"str"}
```

### 3.4 CAST
Type coercion.

```json
{"op":"cast","expr":{"op":"var","name":"count"},"to":"str"}
{"op":"cast","expr":{"op":"var","name":"raw"},  "to":"int"}
```

| to    | Python        | OORexx   | Rust                          |
|-------|---------------|----------|-------------------------------|
| str   | str(x)        | ''||x    | x.to_string()                 |
| int   | int(x)        | x+0      | x.parse::<i64>().unwrap_or(0) |
| float | float(x)      | x+0.0    | x.parse::<f64>().unwrap_or(0.0) |
| bool  | bool(x)       | x==1     | x != 0                        |
| list  | list(x)       | .Array~new | Vec::from(x)                |
| dict  | dict(x)       | .Directory~new | HashMap::from(x)      |

### 3.5 CONCAT
String concatenation. Backends use native idiom.

```json
{"op":"concat",
 "left":{"op":"var","name":"word"},
 "right":{"op":"literal","value":"\t","type":"str"}}
```

Backends: Python `str(l)+str(r)`, OORexx `l||r`, Rust `format!("{}{}",l,r)`

### 3.6 FORMAT  [PLANNED]
Template string with named or positional slots. Preferred over nested CONCAT.

```json
{"op":"format",
 "template":"{word}\t{pos}\n",
 "args":{"word":{"op":"var","name":"word"},
         "pos": {"op":"var","name":"pos"}}}
```

Backends: Python `f"{word}\t{pos}\n"`,
          Rust   `format!("{}\t{}\n", word, pos)`,
          OORexx `word||'09'x||pos||'0a'x`

### 3.7 Binary operators
All take left and right expression fields.

| op  | meaning       | Python | OORexx | Rust |
|-----|---------------|--------|--------|------|
| ADD | addition      | +      | +      | +    |
| SUB | subtraction   | -      | -      | -    |
| MUL | multiply      | *      | *      | *    |
| DIV | divide        | /      | /      | /    |
| MOD | modulo        | %      | //     | %    |
| EQ  | equal         | ==     | =      | ==   |
| NEQ | not equal     | !=     | \=     | !=   |
| GT  | greater       | >      | >      | >    |
| LT  | less          | <      | <      | <    |
| GTE | greater/equal | >=     | >=     | >=   |
| LTE | less/equal    | <=     | <=     | <=   |
| AND | logical and   | and    | &      | &&   |
| OR  | logical or    | or     | \|     | \|\| |

### 3.8 NOT
Logical negation.

```json
{"op":"not","value":{"op":"var","name":"found"}}
```

### 3.9 IN  [PLANNED]
Membership test.

```json
{"op":"in",
 "item": {"op":"var","name":"lang"},
 "collection": {"op":"var","name":"target_langs"}}
```

Backends: Python `item in collection`,
          Rust   `collection.contains(&item)`,
          OORexx `collection~hasIndex(item)` or `wordpos(item,collection)>0`

Replaces the Python-ism `collection.__contains__(item)` pattern.

### 3.10 INDEX
Subscript / element access.

```json
{"op":"index",
 "obj":   {"op":"var","name":"entry"},
 "index": {"op":"literal","value":"word","type":"str"}}
```

Backends: Python `obj[index]`, Rust `obj[&index]` / `obj.get(&index)`,
          OORexx `obj~at(index)`

### 3.11 SLICE  [PLANNED]
Sub-sequence extraction.

```json
{"op":"slice",
 "obj":   {"op":"var","name":"items"},
 "from":  {"op":"literal","value":0},
 "to":    {"op":"literal","value":10}}
```

Backends: Python `obj[from:to]`, Rust `&obj[from..to]`,
          OORexx `obj~section(from+1, to-from)`

### 3.12 TERNARY  [PLANNED]
Inline conditional expression.

```json
{"op":"ternary",
 "cond":  {"op":"gt","left":"score","right":{"op":"literal","value":0}},
 "then":  {"op":"var","name":"score"},
 "else":  {"op":"literal","value":0}}
```

Backends: Python `then if cond else else`,
          Rust   `if cond { then } else { else }`,
          OORexx conditional assignment pattern

### 3.13 LAMBDA  [PLANNED]
Inline anonymous function, primarily for sort keys and map/filter.

```json
{"op":"lambda",
 "params": ["x"],
 "body":   {"op":"index","obj":"x","index":{"op":"literal","value":0}}}
```

Backends: Python `lambda x: body`,
          Rust   `|x| body`,
          OORexx closure or inline .do block (limited support)

### 3.14 IMPL_USE (expression form)
IMPL_USE may appear as an expression when it has a return value.

```json
{"op":"impl_use",
 "name":"preferred.data.jsonl_parse",
 "args":["raw_line"]}
```

### 3.15 METHOD
Object method call expression.

```json
{"op":"method",
 "obj":  {"op":"var","name":"entry"},
 "name": "get",
 "args": [{"op":"literal","value":"word"},{"op":"literal","value":""}]}
```

Note: Python-ism method names (__len__, __contains__, __bool__) are flagged
by the preflight checker. Use IN, LEN (planned), or CAST instead.

---

## 4. TYPE SYSTEM

Types are optional annotations on literals, declares, params, and routines.
Backends without static typing (Python, OORexx, Bash) use them for cast
generation only. Typed backends (Rust, Java, C++) require them for compilation.

### 4.1 Primitive types
str, int, float, bool, bytes

### 4.2 Collection types
list, dict, set, tuple

### 4.3 Typed collections  [PLANNED]
For Rust and Java backends, element types are needed.

```json
{"type": "list<str>"}
{"type": "dict<str,str>"}
{"type": "option<str>"}
```

### 4.4 NULLABLE  [PLANNED]
Marks a value as potentially absent.

```json
{"op":"declare","name":"ipa","type":"option<str>",
 "value":{"op":"nil"}}
```

Backends: Python `Optional[str]` (type hint only),
          Rust   `Option<String>`,
          OORexx `.nil` check pattern

### 4.5 STRUCT / RECORD  [PLANNED]
Named data structure definition (top-level node).

```json
{ "op": "struct",
  "name": "WordEntry",
  "fields": {
    "word":   "str",
    "pos":    "str",
    "topics": "list<str>",
    "ipa":    "option<str>"
  } }
```

Backends: Python `@dataclass`, Rust `struct`, OORexx `::class`

---

## 5. PREFERRED CAPABILITY REGISTRY

Preferred capabilities are cross-language standard library functions.
Backends provide native implementations; specs reference them by name.

| Name                              | Purpose                              |
|-----------------------------------|--------------------------------------|
| preferred.file.stream_lines       | Stream file as line iterator         |
| preferred.data.jsonl_parse        | Parse one JSONL line -> dict or nil  |
| preferred.ui.progress             | Emit progress tick to stderr         |
| preferred.file.multiwrite_open    | Open N files keyed by (lang, suffix) |
| preferred.file.multiwrite_write   | Write to one of the open handles     |
| preferred.file.multiwrite_close   | Flush and close all handles          |
| preferred.file.write_tsv          | Write dict or rows as TSV            |
| preferred.data.soundex_from_ipa   | Build soundex bucket index from IPA  |
| preferred.string.normalise_unicode| NFC normalise a unicode string       |
| preferred.data.soundex            | Soundex key for a string             |

---

## 6. VERSIONING

The `op` field is the stable identity of each node type. New fields on existing
ops are always optional and backward-compatible. New ops are additive.

[PLANNED] nodes are specified here but not yet implemented in any backend.
Backends MUST emit `_p42_unresolved_impl(name)` (or equivalent loud failure)
for any op or impl they do not support, rather than silently generating wrong
code.
