::class CliUiStyleSpan public
::method init
  expose start length style
  use strict arg start, length, style
::attribute start get
::attribute length get
::attribute style get

::class CliUiSyntaxProvider public mixinclass Object
::method spans abstract

::class CliUiSimpleSyntax public inherit CliUiSyntaxProvider
::method spans
  use strict arg language, text
  out=.array~new
  l=language~lower
  if l == "json" then do
    call addWord text,out,"true","keyword"
    call addWord text,out,"false","keyword"
    call addWord text,out,"null","keyword"
  end
  else if l == "python" | l == "py" then do
    do w over "def class import from return if elif else for while try except finally with as lambda yield True False None and or not in is"~makeArray(' ')
      call addWord text,out,w,"keyword"
    end
  end
  else if l == "oorexx" | l == "rexx" then do
    do w over "call do drop else end exit expose forward guard if interpret iterate leave method nop numeric options otherwise parse procedure pull push queue raise reply return say select signal then trace use when"~makeArray(' ')
      call addWord text,out,w,"keyword"
    end
  end
  return out
addWord:
  use arg text,out,w,style
  p=1
  do while p <= text~length
    a=text~caselessPos(w,p)
    if a=0 then leave
    out~append(.CliUiStyleSpan~new(a,w~length,style))
    p=a+w~length
  end
  return
