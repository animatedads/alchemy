::class CliUiCompletionItem public
::method init
  expose label kind insertText prefixLength
  use strict arg label, kind="symbol", insertText=""
  if insertText="" then insertText=label
  prefixLength=0
::attribute label get
::attribute kind get
::attribute insertText get
::attribute prefixLength

::class CliUiCompletionProvider public mixinclass Object
::method complete abstract

::class CliUiCompletionService public
::method init; expose providers; providers=.directory~new
::method register
  expose providers
  use strict arg language, provider
  providers[language~lower]=provider; return self
::method complete
  expose providers
  use strict arg language, source, cursor, variables
  if variables == .nil then variables = .directory~new
  k=language~lower
  if \providers~hasIndex(k) then return .array~new
  return providers[k]~complete(source,cursor,variables)

::class CliUiWordCompletion public inherit CliUiCompletionProvider
::method init; expose words; use strict arg words
::method complete
  expose words
  use strict arg source,cursor,variables
  prefix=""; p=cursor-1
  do while p>0
    ch=source~substr(p,1)
    if \(ch~datatype('A') | ch~datatype('W') | ch='_') then leave
    prefix=ch||prefix; p=p-1
  end
  out=.array~new
  do w over words
    if prefix="" | w~left(prefix~length)~caselessCompare(prefix)=0 then do
      item=.CliUiCompletionItem~new(w)
      item~prefixLength=prefix~length
      out~append(item)
    end
  end
  return out
