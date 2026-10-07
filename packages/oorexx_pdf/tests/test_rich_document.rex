parse arg root out
if root = '' then root = directory()
call directory root
if out = '' then out = 'rich-document.pdf'
report = .PdfFlowReport~new
report~title = 'TPS Operations Review'
report~subtitle = 'Navigation, images, links and flowing tables'
report~headerText = 'INITECH - TPS REPORT CONTROL'
report~footer = 'NotNotes / TPS evidence'
report~addSection('Executive Summary')
report~addParagraph('This report proves structured PDF output from ooRexx with sidebar bookmarks, clickable URI annotations, embedded JPEG evidence, repeated headers and automatic pagination.')
report~addLink('Open the ooRexx project website', 'https://www.oorexx.org/')
report~addJpeg('tests/fixture.jpg', 480, 'Embedded JPEG evidence supplied as a normal PDF image XObject.')
report~addSection('TPS Inventory')
headers=.Array~of('TPS','Owner','Description','State')
widths=.Array~of(70,100,300,80)
t=.PdfTable~new(headers,widths)
t~title='Collected TPS reports'
do i=1 to 42
  owner='User ' || ((i//7)+1)
  desc='TPS report row ' || i || ' with enough narrative to exercise wrapping and multipage table flow while preserving repeated headers.'
  state='READY'; if i//3=0 then state='FILED'
  t~addRow(.Array~of('TPS-' || right(i,3,'0'),owner,desc,state))
end
report~addTable(t)
report~addSection('Management Notes')
report~addParagraph('The final section exists primarily to prove that the outline destination resolves to content after a long automatically paginated table.')
bytes=report~render(out)
say 'PASS rich document' out bytes
::requires 'PdfCore.cls'
