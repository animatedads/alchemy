out = arg(1)
if out = "" then out = "deflate.bin"
data = copies("TPS-2026-001|codex|DRAFT|", 30)
codec = .PdfDeflate~new
compressed = codec~deflate(data)
zlibBytes = codec~zlib(data)
call stream out, 'c', 'open write replace'
call charout out, compressed
call stream out, 'c', 'close'
call stream out || '.zlib', 'c', 'open write replace'
call charout out || '.zlib', zlibBytes
call stream out || '.zlib', 'c', 'close'
say "RAW=" || length(data) || " DEFLATE=" || length(compressed) || " ZLIB=" || length(zlibBytes)
if length(compressed) >= length(data) then do
  say "FAIL compression did not reduce repetitive test data"
  exit 1
end
say "PASS raw deflate"
::requires 'PdfDeflate.cls'
