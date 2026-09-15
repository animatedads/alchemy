::class FakeRelationshipBankPort subclass FederationBankRelationshipBankPort public
::method init
  expose commands failNextFlag
  commands=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method submit
  expose commands failNextFlag
  use arg command
  if failNextFlag then do; failNextFlag=.false; return .FederationBankRelationshipServiceResult~failure("BANK_DOWN"); end
  commands~append(command); return .FederationBankRelationshipServiceResult~success(command~commandId)
::method commands
  expose commands
  return commands
::requires "FederationBankRelationshipAdapterService.cls"
