# Plan42 / TUTOR String Suffix Note

Do not blindly rewrite the TUTOR BYTES suffix in this source tree from `Y` to
`B`.

In the bundled `tools/tutor-0.6a` and `tools/rexx-parser-0.6` sources, `B` is
already the classic Rexx binary-string suffix, while TUTOR BYTES strings use `Y`.

Evidence in this package:

- `tools/tutor-0.6a/doc/string-types/readme.md` says `B` was already taken for
  binary strings and therefore BYTES uses `Y`.
- `tools/tutor-0.6a/samples/basictour.rxu` describes BYTES strings as
  `'string'Y`.
- `tools/rexx-parser-0.6/bin/Scanner.cls` routes `B` to `BinaryString` and `Y` to
  `BytesString`.
- `tools/rexx-parser-0.6/bin/Elements.cls` decodes `B` as binary and includes `Y`,
  `P`, `G`, and `T` in the Unicode/TUTOR string set.

If another agent reports that a newer TUTOR source uses `B` for BYTES, treat that
as a version conflict to verify against that exact source, not as a correction to
this uploaded 0.6a tree.
