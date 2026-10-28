/* PdfNotNotes.cls - generic NotNotes document -> PdfReport adapter. */

::class PdfNotNotesRenderer public

::method reportFor
  use strict arg document
  report = .PdfReport~new
  identity = self~identityFor(document)
  report~title = document~formName
  report~subtitle = identity || " | Revision " || document~revision
  report~footer = "NotNotes document " || document~documentId

  names = document~fieldNames
  do name over names
    value = document~field(name)
    if value == .nil then value = ""
    report~addField(self~label(name), value)
  end
  report~addField("Approval Status", document~ApprovalStatus)
  return report

::method write
  use strict arg document, path
  return self~reportFor(document)~render(path)

::method identityFor private
  use strict arg document
  preferred = .Array~of("TPSNumber", "DocKey", "DocumentNumber", "Reference")
  names = document~fieldNames
  do wanted over preferred
    do actual over names
      if actual~upper = wanted~upper then do
        value = document~field(actual)
        if value \== .nil then do
          value = value~string~strip
          if value <> "" then return value
        end
      end
    end
  end
  return document~documentId

::method label private
  use strict arg name
  /* Conservative camel-case splitter; preserves acronym-like names. */
  out = ""
  prevLower = .false
  do i = 1 to length(name)
    ch = substr(name, i, 1)
    isUpper = ch >= "A" & ch <= "Z"
    if i > 1 & isUpper & prevLower then out = out || " "
    out = out || ch
    prevLower = (ch >= "a" & ch <= "z")
  end
  return out

::requires 'PdfCore.cls'
