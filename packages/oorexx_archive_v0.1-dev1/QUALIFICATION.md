# Qualification

Required qualification is pure ooRexx plus the standard ooRexx utility
routines used for the fresh-directory test. It does not invoke `unzip`, `zip`,
Python, Java or zlib.

`tests/test_native.rex` proves:

- Stored writer/reader round trip;
- method-8 fixed-Huffman writer/reader round trip;
- embedded dynamic-Huffman method-8 decoding;
- data-descriptor handling;
- CRC corruption rejection;
- traversal and absolute-name rejection;
- portable case-fold collision rejection;
- Unix symlink rejection;
- entry/per-entry/total declared-size limits;
- live bounded-DEFLATE rejection when compressed data expands beyond dishonest
  declared metadata;
- EOCD trailing-data rejection;
- fresh-root nested extraction and rejection of an existing root.

`tests/run_interop.sh` is optional reference evidence. It proves that `unzip`
accepts a native writer archive and that the native reader decodes an ordinary
`zip -9` archive.
