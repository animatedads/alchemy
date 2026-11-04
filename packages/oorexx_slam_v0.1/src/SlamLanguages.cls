/* SlamLanguages.cls - which reader a file needs, by its extension: ooRexx, NetRexx, Java or C++.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Every reader makes the same segment kinds, so the store, edges, weights and Task do not change.
 */
::requires 'SlamSegmenter.cls'
::requires 'SlamJava.cls'
::requires 'SlamCpp.cls'
::requires 'SlamNetRexx.cls'

::class SlamLanguages public
::method of class
  use strict arg file
  base = file~substr(file~lastPos('/') + 1)
  if base~pos('.') == 0 then do
    /* no extension: a file that says it is C++ on its first line (libc++'s <vector>, <string>: an
       editor mode line '-*- C++ -*-') is read as C++; anything else is not read */
    first = linein(file)
    call stream file, 'C', 'CLOSE'
    if first~pos('-*- C++ -*-') > 0 then return 'CPP'
    return ''
  end
  ext = file~substr(file~lastPos('.') + 1)~lower
  if wordpos(ext, 'cls rex rexx orx testgroup testunit frm') > 0 then return 'REXX'      /* ooTest's tests and framework too */
  if ext == 'nrx' then return 'NETREXX'
  if ext == 'java' then return 'JAVA'
  if wordpos(ext, 'cpp cc cxx hpp hh hxx h c inc') > 0 then return 'CPP'          /* C, too: the nearest reader */
  return ''
::method splitter class
  use strict arg lang
  if lang == 'JAVA' then return .SlamJavaSplitter~new
  if lang == 'CPP' then return .SlamCppSplitter~new
  if lang == 'NETREXX' then return .SlamNrxSplitter~new
  return .SlamUnitSplitter~new
::method segmenter class
  use strict arg lang
  if lang == 'JAVA' then return .SlamJavaSegmenter~new
  if lang == 'CPP' then return .SlamCppSegmenter~new
  if lang == 'NETREXX' then return .SlamNrxSegmenter~new
  return .SlamSegmenter~new
