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
  ext = file~substr(file~lastPos('.') + 1)~lower
  if wordpos(ext, 'cls rex rexx orx') > 0 then return 'REXX'
  if ext == 'nrx' then return 'NETREXX'
  if ext == 'java' then return 'JAVA'
  if wordpos(ext, 'cpp cc cxx hpp hh hxx h') > 0 then return 'CPP'
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
