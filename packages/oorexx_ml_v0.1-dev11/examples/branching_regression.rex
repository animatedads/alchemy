rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3))
model=.MLLinearRegression~new('demo-regression')
root=model~journalPoint
model~fit(.MLDataset~new(rows,.array~of(1,3,5,7)))
say 'main prediction x=4:' model~predictDecimal(.array~of(4))
model~rollback(root,'2x-plus-1')
model~fit(.MLDataset~new(rows,.array~of(1,4,7,10)))
say 'alternate prediction x=4:' model~predictDecimal(.array~of(4))
model~rollForward('2x-plus-1')
say 'restored old future x=4:' model~predictDecimal(.array~of(4))
::requires "OorexxML.cls"
