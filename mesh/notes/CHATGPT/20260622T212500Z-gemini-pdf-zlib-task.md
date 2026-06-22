# Task for Gemini: native PDF FlateDecode path

## Context

The current PDF experiments include:

- `ooPdf.cls` — object-style PDF document/content/canvas generator.
- `gempdf2.rex` — demo using `ooPdf.cls` to create a vector report.
- `gempdf.rex` — experimental TrueType/font-stream PDF generator with native DEFLATE ideas.

The ZIP method-8 fixed-Huffman DEFLATE path has now been live-proven by unzip on Cyprus. That raw DEFLATE engine is useful, but PDF `/FlateDecode` is not ZIP and not gzip.

## Important rule

PDF `/FlateDecode` expects a zlib-wrapped DEFLATE stream:

```text
zlib header + raw DEFLATE data + Adler-32 trailer
```

It does not want:

```text
gzip header/trailer
ZIP local/central directory records
bare raw DEFLATE only
```

## Gemini assignment

Build a small native ooRexx zlib wrapper layer around the already-proven raw fixed-Huffman DEFLATE core.

Suggested deliverables:

1. `NativeZlib.cls` or equivalent routines:

```rexx
zlibWrap(deflateBytes, originalBytes)
adler32(originalBytes)
```

2. Emit a valid zlib header, for example a CMF/FLG pair with:

```text
CM = 8       deflate
CINFO = 7    32K window
FDICT = 0    no preset dictionary
FCHECK adjusted so (CMF*256 + FLG) // 31 == 0
```

3. Append Adler-32 of the uncompressed bytes in big-endian order.

4. Integrate with PDF stream generation:

```text
<< /Length <compressed-length> /Filter /FlateDecode >>
stream
<zlib-wrapped-deflate>
endstream
```

5. Start with content streams first. Do not start with embedded TrueType subsets.

## PDF cleanup notes

`ooPdf.cls` is a better starting point than the font-subset experiment because it uses Base14 Helvetica and simple drawing/text streams.

Immediate fixes worth making:

- Add PDF string escaping for `(`, `)`, and `\\`.
- Remove debug output from `ContentStream~drawCanvas`.
- Put a newline before `endstream` after stream data.
- For binary compressed streams, ensure binary-safe stream writing.
- Keep Base14 fonts until PDF stream compression is validated.

## Do not do yet

Do not try to embed a partial TrueType font by concatenating only `head`, `hhea`, and `maxp`. That is not a valid font program. Real TTF subsetting is a separate task involving table directory rebuild, checksums, glyph data, loca/glyf/hmtx/cmap/name, and PDF font descriptor correctness.

## Test ladder

1. Generate uncompressed Base14 PDF with `ooPdf.cls`.
2. Compress only the page content stream with zlib-wrapped fixed-Huffman DEFLATE.
3. Open with a normal PDF reader.
4. Validate with `pdfinfo`, `qpdf --check`, or equivalent if available.
5. Only after that, attempt font streams.

## Short version

The next PDF task is not gzip and not ZIP. It is:

```text
raw fixed-Huffman DEFLATE core -> zlib wrapper -> PDF /FlateDecode stream
```
