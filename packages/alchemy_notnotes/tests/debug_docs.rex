n=.AlchemyNotNotesNode~new('N')
a=n~createDocument('Customer'); a~CompanyName='A'; n~save(a)
b=n~createDocument('Customer'); b~CompanyName='B'; n~save(b)
x=n~documents(.Document~type('Customer'))
say 'x=' x
say 'x class=' x~class
::requires 'src/AlchemyNotNotes.cls'
