#!/usr/bin/env python3
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
original = root / 'librarian/source/librarian_wordnet_oorexx.rex.original'
core = root / 'librarian/LibrarianSalvagedCore_v09.cls'

original_bytes = original.read_bytes()
assert hashlib.sha256(original_bytes).hexdigest() == 'cfaf24c475f99008388f58cd2b43ba900deaad24af286a6e264fb2684045ac5e'
text = original_bytes.decode('utf-8')

# Mechanical class-library extraction: source executable bootstrap is lines 1..12.
lines = text.splitlines(keepends=True)
expected = ''.join(lines[12:])

assert expected.count('~allItems(') == 11
expected = expected.replace('~allItems(', '~allAt(')

old = """::method expand
  use arg wordObj, relationNames, maxDepth
  seen = .Directory~new
  result = .Array~new
  if wordObj = .nil then return result
"""
new = """::method expand
  use arg wordObj, relationNames, maxDepth
  seen = .Directory~new
  expandedWords = .Array~new
  if wordObj = .nil then return expandedWords
"""
assert old in expected
expected = expected.replace(old, new, 1)
expected = expected.replace('          result~append(nextWord)', '          expandedWords~append(nextWord)', 1)
expected = expected.replace('  return result\n\n::method edgeSupplier', '  return expandedWords\n\n::method edgeSupplier', 1)

old = """::routine MergeWordLists public
  use arg a, b
  result = a
  do i = 1 to words(b)
    result = AddUniqueWord(result, word(b, i))
  end
  return result
"""
new = """::routine MergeWordLists public
  use arg a, b
  mergedWords = a
  do i = 1 to words(b)
    mergedWords = AddUniqueWord(mergedWords, word(b, i))
  end
  return mergedWords
"""
assert old in expected
expected = expected.replace(old, new, 1)

actual = core.read_text()
assert actual == expected, 'LibrarianSalvagedCore_v09.cls contains changes outside the declared salvage delta'
assert '~allItems(' not in actual
assert '  result = ' not in actual
print('LIBRARIAN SALVAGE DELTA: OK')
