/*----------------------------------------------------------------------------*/
/* ForeignPngProvider.cls  (ooRexx Compress v0.1-dev3)                        */
/* Optional accelerated indexed-PNG encoder: Python zlib through the ooRexx   */
/* Foreign Runtime. Rows go in as text and base64 comes back, so no binary    */
/* crosses the bridge. Inject into IndexedPngEncoder as its provider.         */
/* Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.      */
/*----------------------------------------------------------------------------*/
::class ForeignPngProvider public
::method available class
  signal on syntax name nope
  if .environment~hasEntry('FOREIGNPYTHON') = 0 then .context~package~loadPackage('python_foreign.cls')
  return .ForeignPython~canImport('zlib') & .ForeignPython~canImport('oorexx_compress_native')
nope:
  return .false
::method init
  expose native
  if \.ForeignPngProvider~available then raise syntax 88.900 array('ForeignPngProvider needs the Foreign Runtime Python bridge and oorexx_compress_native')
  native = .ForeignPython~import('oorexx_compress_native')
::method name
  return 'FOREIGN'
::method indexedPngBase64
  expose native
  use strict arg rows, paletteSpec, scale
  return native~indexed_png_base64(rows, paletteSpec, scale)
