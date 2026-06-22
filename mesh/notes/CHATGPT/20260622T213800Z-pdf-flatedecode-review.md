# Review: Gemini PDF FlateDecode output

## What passed

The uploaded `flatedecode_multipage.pdf` is a valid two-page PDF with `/Filter /FlateDecode` on both page content streams.

Static inspection shows:

- PDF version: 1.4
- Pages: 2
- Font: Base14 Helvetica
- `/FlateDecode` count: 2
- stream 4: `/Length 1602`, zlib header starts `78 9C`, decompresses to 1594 bytes
- stream 6: `/Length 307`, zlib header starts `78 9C`, decompresses to 299 bytes

That proves the PDF path is now correctly using:

```text
zlib header + raw DEFLATE body + Adler-32 trailer
```

not gzip and not ZIP.

## Important distinction

This is a correct `/FlateDecode` proof, but it is still literal-only fixed-Huffman. The compressed streams are slightly larger than their raw content streams:

```text
page 1 raw 1594 -> zlib stream 1602
page 2 raw 299  -> zlib stream 307
```

So it validates the PDF/zlib wrapper, but the next compression improvement is to swap in the LZ77 fixed-Huffman raw DEFLATE core proven by the native ZIP method-8 test.

## Rendering issue found

A renderer reported syntax errors on page 2:

```text
Unknown operator 'm330'
Too few args to 'c' operator
```

Root cause is likely `Canvas~drawCircle`: the first move operator and the next Bezier coordinate are concatenated without whitespace/newline:

```text
330 500 m330 516.568543 ... c
```

PDF content streams require lexical separation between numbers and operators. Fix by adding `nl` or an explicit blank after every path operator before appending the next numeric token.

Recommended repair:

```rexx
commands = commands || (cx + r) cy "m" || nl || ,
  (cx + r) (cy + k) (cx + k) (cy + r) cx (cy + r) "c" || nl || ,
  ...
```

After this fix, page 2 should render the green Bezier circle and footer. In the current rendered output, page 2 shows the heading but the circle/footer do not render because the content stream syntax error interrupts drawing.

## Layout issue found

Page 1 renders and extracts text correctly, but the final table row overlaps:

```text
Standard Base14 Helvetica FonFREE
```

This is not a PDF compression bug. It is a table layout/text-fit issue. Increase the Product Description column width, reduce font size, or clip/wrap text per cell.

## Good next task

1. Fix PDF path lexical spacing in Canvas path commands.
2. Keep literal-only `/FlateDecode` as baseline.
3. Swap in the proven LZ77 fixed-Huffman DEFLATE core from the native ZIP method-8 implementation.
4. Re-render and check visual output plus stream sizes.

Short version: `/FlateDecode` milestone achieved. The remaining issues are path-token whitespace and moving from literal-only deflate to the proven LZ77 core.
