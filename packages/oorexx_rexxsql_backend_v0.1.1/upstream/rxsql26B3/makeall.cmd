/**/
Trace o
Parse Arg db .
If db = '' Then db = 'saw ora min2 min sol udbc db2'
'mkdir dist'
Do i = 1 To Words(db)
   this = Word(db,i)
   'cd dist'
   'mkdir' this
   'cd ..'
   'mkdir' this
   'cd' this
   'mkdir os2'
   'cd os2'
   'nmake -f \rexxsql\iccos2.mak DB=' || Translate(this)
   If rc \= 0 Then Leave
   'cd ..\..'
End
'cd \rexxsql'
