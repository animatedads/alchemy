s=.IBM370Storage~new(65536)
s~storeHex(254,"A1B2C3D4")
call eq s~fetchHex(254,4),"A1B2C3D4","cross-page write/read"
call eq s~mappedPageNumbers~items,2,"two mapped pages"
s~storeHex(255,"0000")
call eq s~fetchHex(254,4),"A10000D4","zero subrange"
call eq s~mappedPageNumbers~items,2,"surviving bytes keep both pages mapped"
s~storeHex(254,"0000")
call eq s~mappedPageNumbers~items,1,"empty first page removed"
s~storeHex(256,"0000")
s~storeHex(258,"0000")
call eq s~mappedPageNumbers~items,0,"empty second page removed"
say 'PASS test_storage_small_fastpath'
exit 0
eq: procedure
 parse arg a,b,label
 if a \== b then do; say 'FAIL' label 'expected='||b 'actual='||a; exit 1; end
 return
::requires 'IBM370Architecture.cls'
