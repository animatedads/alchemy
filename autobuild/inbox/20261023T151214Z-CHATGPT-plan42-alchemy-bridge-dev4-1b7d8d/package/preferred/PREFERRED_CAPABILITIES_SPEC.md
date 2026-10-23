# Plan42 Preferred Capability Registry -- Extension Specification

Current capabilities (already in preferred.capabilities.json):
  preferred.file.stream_lines, preferred.data.jsonl_parse,
  preferred.ui.progress, preferred.file.multiwrite_open/write/close,
  preferred.file.write_tsv, preferred.data.soundex_from_ipa,
  preferred.string.normalise_unicode, preferred.data.soundex

---

## preferred.log.*

Structured logging. OORexx backend routes to the Alchemy framework logger.
Other backends use their language's standard logging facility.

| Name                      | Params          | Returns | Notes                        |
|---------------------------|-----------------|---------|------------------------------|
| preferred.log.debug       | message:str     | void    |                              |
| preferred.log.info        | message:str     | void    |                              |
| preferred.log.warn        | message:str     | void    |                              |
| preferred.log.error       | message:str     | void    |                              |
| preferred.log.fatal       | message:str     | void    | exits after logging          |
| preferred.log.structured  | level, key, val | void    | key=value structured output  |

Backend implementations:
  python3:  logging.{level}({message})
  oorexx:   .AlchemyLogger~{level}({message})   -- framework logger
  rust:     eprintln!("[{level}] {}", {message}) -- or log crate
  c:        fprintf(stderr, "[LEVEL] %s\n", message)
  regina:   say "[LEVEL]" message

---

## preferred.cli.*

Command-line argument parsing. Generates stable, idiomatic CLI boilerplate.
The spec declares what arguments are expected; each backend uses its
native facility.

| Name                      | Params                         | Returns | Notes                        |
|---------------------------|--------------------------------|---------|------------------------------|
| preferred.cli.string      | name, default, help            | str     | --name value                 |
| preferred.cli.int         | name, default, help            | int     | --name integer               |
| preferred.cli.flag        | name, help                     | bool    | --name (boolean switch)      |
| preferred.cli.positional  | name, help                     | str     | positional argument          |
| preferred.cli.list        | name, sep, help                | list    | --name a,b,c -> [a,b,c]     |

Backend implementations:
  python3:  argparse.ArgumentParser() / add_argument / parse_args()
  oorexx:   parse arg ... / use arg ... (Rexx idiom)
  rust:     std::env::args() match loop (already in emitEntryPoint)
  c:        getopt_long() or manual argv loop
  regina:   PARSE ARG / ARG()

Note: preferred.cli.* is consumed by the entry point generator, not inline.
The emitEntryPoint method reads the routine param_types to select the right
CLI parser pattern per backend.

---

## preferred.crypto.*

Cryptographic primitives. OORexx uses crypto.cls from the Alchemy stack.

| Name                       | Params           | Returns | Notes                    |
|----------------------------|------------------|---------|--------------------------|
| preferred.crypto.sha256    | data:str         | str     | hex digest               |
| preferred.crypto.sha512    | data:str         | str     | hex digest               |
| preferred.crypto.md5       | data:str         | str     | hex digest (legacy)      |
| preferred.crypto.hmac_sha256| key, data       | str     | hex HMAC                 |
| preferred.crypto.base64_enc| data:str         | str     | base64 encoded           |
| preferred.crypto.base64_dec| data:str         | str     | base64 decoded           |
| preferred.crypto.rand_hex  | n:int            | str     | n random hex bytes       |
| preferred.crypto.encrypt   | key, data        | str     | AES-256-GCM ciphertext   |
| preferred.crypto.decrypt   | key, ciphertext  | str     | AES-256-GCM plaintext    |

Backend implementations:
  python3:  hashlib / hmac / base64 / cryptography.hazmat
  oorexx:   crypto.cls (RSA/ChaCha20/SHA512 -- already built)
  rust:     sha2 / hmac / base64 / aes-gcm crates
  c:        openssl/libsodium
  regina:   sha256 via B2X/C2X builtin + external call fallback

---

## preferred.math.*

Mathematical functions. All backends have native equivalents.

| Name                       | Params     | Returns | Notes                    |
|----------------------------|------------|---------|--------------------------|
| preferred.math.floor       | x:float    | int     |                          |
| preferred.math.ceil        | x:float    | int     |                          |
| preferred.math.round       | x, n:int   | float   | n decimal places         |
| preferred.math.sqrt        | x:float    | float   |                          |
| preferred.math.pow         | x, n       | float   |                          |
| preferred.math.log         | x:float    | float   | natural log              |
| preferred.math.log2        | x:float    | float   |                          |
| preferred.math.log10       | x:float    | float   |                          |
| preferred.math.abs         | x          | float   |                          |
| preferred.math.min         | a, b       | float   |                          |
| preferred.math.max         | a, b       | float   |                          |
| preferred.math.clamp       | x, lo, hi  | float   | lo <= result <= hi       |
| preferred.math.pi          | (none)     | float   | 3.14159...               |
| preferred.math.e           | (none)     | float   | 2.71828...               |
| preferred.math.is_nan      | x          | bool    |                          |
| preferred.math.is_inf      | x          | bool    |                          |

Backend implementations:
  python3:  math.floor / math.ceil / math.sqrt etc.
  oorexx:   FLOOR() CEIL() SQRT() (built-in Rexx functions)
  rust:     f64::floor / f64::ceil / f64::sqrt etc.
  c:        floor() ceil() sqrt() from <math.h>
  regina:   FLOOR() CEIL() SQRT() (same as OORexx)

---

## preferred.tsv.*

TSV read/write beyond the existing write_tsv. Streaming and random access.

| Name                        | Params           | Returns    | Notes                  |
|-----------------------------|------------------|------------|------------------------|
| preferred.tsv.stream        | path             | iterator   | yield one row/line     |
| preferred.tsv.read_all      | path             | list<list> | full file into memory  |
| preferred.tsv.write_rows    | rows, path       | void       | list of lists -> tsv   |
| preferred.tsv.parse_line    | line             | list       | split on tab           |
| preferred.tsv.format_line   | fields:list      | str        | join with tab + \n     |
| preferred.tsv.write_dict    | data, path       | void       | dict -> key\tvalue\n   |
| preferred.tsv.merge_file    | path, key_col    | void       | dedup + merge in-place |
| preferred.tsv.index_by      | path, col:int    | dict       | col as key -> rows     |

Note: preferred.file.write_tsv (existing) handles dict<str,list<str>>.
      preferred.tsv.* is the fuller, more structured API.

---

## preferred.yaml.*

YAML serialisation/deserialisation.

| Name                       | Params       | Returns | Notes                    |
|----------------------------|--------------|---------|--------------------------|
| preferred.yaml.load        | path:str     | dict    | file -> object tree      |
| preferred.yaml.loads       | text:str     | dict    | string -> object tree    |
| preferred.yaml.dump        | data, path   | void    | object tree -> file      |
| preferred.yaml.dumps       | data:dict    | str     | object tree -> string    |
| preferred.yaml.merge       | base, over   | dict    | deep merge two dicts     |

Backend implementations:
  python3:  import yaml (PyYAML / ruamel.yaml)
  oorexx:   .Yaml class (native in OORexx 5.2.0, April 2026 -- no ::requires needed)
            Method names: fromFile/fromString/toFile/toString -- verify against 5.2.0 docs
  rust:     serde_yaml crate
  c:        libyaml
  regina:   external call to python3 -c 'import yaml...' or bundled parser

---

## preferred.json.*

JSON beyond jsonl_parse. Full file and string handling.

| Name                       | Params       | Returns | Notes                    |
|----------------------------|--------------|---------|--------------------------|
| preferred.json.load        | path:str     | dict    | file -> object           |
| preferred.json.loads       | text:str     | dict    | string -> object         |
| preferred.json.dump        | data, path   | void    | object -> file           |
| preferred.json.dumps       | data         | str     | object -> string         |
| preferred.json.dumps_pretty| data         | str     | indented output          |

Backend implementations:
  python3:  import json / json.load / json.dumps
  oorexx:   json.cls (already in use)
  rust:     serde_json::from_reader / serde_json::to_string_pretty
  c:        cJSON / jansson library
  regina:   external call or bundled parser

---

## preferred.string.*  (extending existing)

| Name                          | Params          | Returns | Notes                      |
|-------------------------------|-----------------|---------|----------------------------|
| preferred.string.normalise_unicode | text       | str     | NFC normalise (existing)   |
| preferred.string.strip        | text:str        | str     | trim whitespace            |
| preferred.string.split        | text, sep       | list    | split on separator         |
| preferred.string.join         | parts, sep      | str     | join list with separator   |
| preferred.string.replace      | text, old, new  | str     | replace all occurrences    |
| preferred.string.starts_with  | text, prefix    | bool    |                            |
| preferred.string.ends_with    | text, suffix    | bool    |                            |
| preferred.string.pad_left     | text, width, ch | str     | left-pad to width          |
| preferred.string.pad_right    | text, width, ch | str     | right-pad to width         |
| preferred.string.upper        | text:str        | str     |                            |
| preferred.string.lower        | text:str        | str     |                            |
| preferred.string.contains     | text, sub       | bool    |                            |
| preferred.string.count        | text, sub       | int     | count occurrences          |
| preferred.string.slugify      | text:str        | str     | url-safe slug              |
| preferred.string.truncate     | text, n, ellip  | str     | truncate to n chars        |

---

## preferred.time.*

| Name                       | Params       | Returns | Notes                    |
|----------------------------|--------------|---------|--------------------------|
| preferred.time.now_unix    | (none)       | int     | unix timestamp seconds   |
| preferred.time.now_iso     | (none)       | str     | ISO 8601 timestamp       |
| preferred.time.sleep       | seconds:int  | void    |                          |
| preferred.time.format      | unix, fmt    | str     | strftime-style format    |
| preferred.time.elapsed     | start:int    | float   | seconds since start      |

---

## Prioritisation

Immediate (needed now):
  preferred.log.*       -- OORexx logger wiring is critical for Alchemy
  preferred.cli.*       -- every script needs this; emitEntryPoint improvement
  preferred.json.*      -- already half-done via json.cls; formalise it

Medium (next sprint):
  preferred.tsv.*       -- extend what we have
  preferred.math.*      -- simple; all backends trivial
  preferred.string.*    -- extend what we have
  preferred.time.*      -- simple

Immediate:
  preferred.yaml.*      -- .Yaml native class in OORexx 5.2.0
  preferred.crypto.*    -- wire to existing crypto.cls for OORexx

---

## Registry format for preferred.capabilities.json

Each entry:
{
  "name": "preferred.log.info",
  "abstract": "Emit an informational log message.",
  "params": ["message"],
  "param_types": {"message": "str"},
  "return_type": "void",
  "type": "inline",
  "implementations": {
    "python3":  {"type":"inline","inline":"logging.info({message})"},
    "oorexx":   {"type":"inline","inline":".AlchemyLogger~getInstance~info({message})"},
    "rust":     {"type":"runtime","runtime":"p42_log_info"},
    "c":        {"type":"runtime","runtime":"p42_log_info"},
    "regina":   {"type":"inline","inline":"say '[INFO]' {message}"}
  }
}

Note: OORexx yaml.cls object representation (5.2.0):
  YAML mappings  -> Table objects   (NOT Directory -- different from json.cls)
  YAML sequences -> Array objects
  YAML null      -> .nil
  YAML booleans  -> YamlBoolean singletons (.isA(.YamlBoolean) for type check)
  YAML scalars   -> plain ooRexx strings
  With preserveTags=.true: tagged nodes wrapped in YamlTagged objects

Note: OORexx json.cls object representation (5.2.0):
  JSON objects   -> Directory objects
  JSON arrays    -> Array objects
  JSON null      -> .nil
  JSON booleans  -> JsonBoolean singletons (.isA(.JsonBoolean) for type check)
  JSON strings   -> JsonString instances (subclass of String)
  JSON numbers   -> plain ooRexx strings

Note: csvStream class (OORexx 5.2.0):
  .csvStream~new(path, hasHeaders) then ~open(mode)
  ~CSVLineIn  -> Array of fields
  ~CSVLineOut(collection) -> writes row
  Delimiter default: comma. Qualifier default: double-quote.
  HEADERS attribute gives column definitions when hasHeaders=.true
