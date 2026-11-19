/* Texts.cls - a fixture: the text of a ::resource is data, so nothing in it is a finding. */
::class Texts public
::constant MODULE_VERSION '0.2'
::constant MODULE_LASTCHANGED '2026-11-19'

::method help
  return .resources~helpText

::resource helpText
result = 1 and x = y + 0 are only words here, as are '|'b and '"'(x)
::method hidden private
::END
::resource other end "@@"
do i = 1 to list~items
@@
