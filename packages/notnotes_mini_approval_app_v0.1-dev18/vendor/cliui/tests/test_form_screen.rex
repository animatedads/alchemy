renderer=.CliUiHeadlessRenderer~new(14,72)
choices=.array~new
choices~append(.CliUiChoice~new('CUSTOMER-00017','Acme Engineering'))
choices~append(.CliUiChoice~new('CUSTOMER-00023','Central Hydraulics'))
form=.CliUiFormModel~new('Purchase Request')
form~addField(.CliUiField~new('request','Request','PR-1002',.false))
form~addField(.CliUiField~new('company','CompanyName','Acme Engineering'))
status=.CliUiSelectionField~new('status','Status','PENDING',.array~new,'PENDING')
form~addField(status)
customer=.CliUiSelectionField~new('customer','Customer','Acme Engineering',choices,'CUSTOMER-00017')
form~addField(customer)
if form~focusIndex<>2 then raise syntax 93.900 array ('first editable field focus failed')
form~moveFocus(1)
form~moveFocus(1)
if form~focusedField~identity<>'customer' then raise syntax 93.900 array ('focus navigation failed')
if customer~moveChoice(1)<>'CUSTOMER-00023' then raise syntax 93.900 array ('stable selection identity failed')
if customer~value<>'Central Hydraulics' then raise syntax 93.900 array ('selection display label failed')
screen=.CliUiScreenModel~new('Mini NotNotes')
screen~navigation=.array~of('Documents','Views','Approval Queue')
screen~form=form
screen~status='PR-1002 | modified'
screen~prompt=.CliUiPromptModel~new('Command: ')
.CliUiScreenProjection~new(renderer)~render(screen,14,72)
if renderer~cell(4,1)=.nil then raise syntax 93.900 array ('form title projection missing')
if renderer~cell(8,1)=.nil then raise syntax 93.900 array ('selection field projection missing')
wideIdentity=customer~selectedIdentity
renderer~resize(10,32)
.CliUiScreenProjection~new(renderer)~render(screen,10,32)
if customer~selectedIdentity<>wideIdentity then raise syntax 93.900 array ('resize changed stable identity')
if renderer~cell(4,1)=.nil then raise syntax 93.900 array ('narrow projection missing')
say 'PASS form labels fields selection stable identity wide narrow screen'

::requires 'CliUiForm.cls'
::requires 'CliUiModels.cls'
::requires 'CliUiScreen.cls'
::requires 'CliUiHeadlessRenderer.cls'
