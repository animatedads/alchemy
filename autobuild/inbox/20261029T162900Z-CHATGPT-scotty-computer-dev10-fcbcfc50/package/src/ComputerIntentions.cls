/* Invocation-specific intention source.  There is no permanent capability list.
   IntentionService~input() calls discovery afresh before proposal resolution. */
::class ComputerDiscovery public
::method init
  expose root
  use arg root
::method discover
  expose root
  use arg service
  backend = root || '/src/ComputerActions.py'
  if stream(backend, 'C', 'QUERY EXISTS') == '' then return .nil
  ssh = value('COMPUTER_SSHNODE',, 'ENVIRONMENT')
  if ssh == '' then ssh = root || '/adapters/sshnode.sh'
  cloud = value('COMPUTER_CLOUDCTL',, 'ENVIRONMENT')
  if cloud == '' then cloud = root || '/adapters/cloudctl.sh'
  sshAvailable = stream(ssh, 'C', 'QUERY EXISTS') \== ''
  cloudAvailable = stream(cloud, 'C', 'QUERY EXISTS') \== ''
  revision = 'A1-' || sshAvailable || '-' || cloudAvailable
  snapshot = .IntentionDiscoverySnapshot~new('COMPUTER.WORKSTATION', revision)
  snapshot~addEvidenceFact(.IntentionEvidenceFact~new('COMPUTER', 'BACKEND_AVAILABLE', 'YES', 100, 'FILESYSTEM', 'OBSERVED', revision))
  provider = .ComputerIntentionProvider~new(sshAvailable, cloudAvailable)
  snapshot~addSurfaceAdvertisement(.IntentionSurfaceAdvertisement~new('COMPUTER.LOCAL', provider, root, 'LOCAL', 'WORKSTATION', 'DISCOVERY', 'USER'))
  return snapshot

::class ComputerIntentionProvider public
::method init
  expose sshAvailable cloudAvailable
  use arg sshAvailable, cloudAvailable
::method propose
  expose sshAvailable cloudAvailable
  use arg service, utterance
  u = translate(strip(utterance))
  id = ''
  if left(u, 7) == '--JSON ' then u = strip(substr(u, 8))
  if u == 'HELP' | u == '--HELP' | u == '-H' then id = 'HELP'
  else if u == 'INSTRUCTIONS' | u == 'COMPUTER INSTRUCTIONS' then id = 'INSTRUCTIONS'
  else if left(u, 7) == 'SHA256 ' | left(u, 7) == 'SHA512 ' | left(u, 5) == 'SHA1 ' | left(u, 8) == 'COMPARE ' | left(u, 7) == 'VERIFY ' | left(u, 12) == 'FIND SHA256 ' | left(u, 8) == 'INSPECT ' | left(u, 9) == 'LIST ZIP ' | left(u, 9) == 'TEST ZIP ' | left(u, 4) == 'GET ' | left(u, 10) == 'CALCULATE ' | left(u, 5) == 'HASH ' then id = 'FILE_INTEGRITY'
  else if u == 'SEARCH SCOPES' | u == 'LIST SEARCH LOCATIONS' | u == 'LIST SEARCH SCOPES' then id = 'SEARCH_SCOPES'
  else if left(u, 7) == 'GITHUB ' then id = 'GITHUB'
  else if left(u, 26) == 'FIND DIRECTORIES MATCHING ' then id = 'FIND_DIRECTORIES'
  else if left(u, 4) == 'JOB ' then id = 'JOBS'
  else if left(u, 11) == '--JSON JOB ' then id = 'JOBS'
  else if left(u, 14) == 'READ DOCUMENT ' | left(u, 15) == 'LIST DOCUMENTS ' then id = 'READ_DOCUMENT'
  else if left(u, 6) == 'LEARN ' then id = 'LEARN'
  else if left(u, 3) == 'DO ' then id = 'RUN_LEARNED'
  else if left(u, 16) == 'FIND DEPENDENCY ' | (left(u, 5) == 'FIND ' & pos(' IN LAST ', u) > 0) then id = 'SEARCH_NAMED'
  else if u == 'DISCOVER' | u == 'WHAT CAN YOU DO' | u == 'INTENTIONS' then id = 'DISCOVER'
  else if u == 'CONFIG' | u == 'SHOW CONFIG' | u == 'SHOW MY FIND FILE LOCATIONS' then id = 'CONFIG_SHOW'
  else if left(u, 9) == 'REGISTER ' then id = 'ADD_SEARCH_SCOPE'
  else if left(u, 4) == 'ADD ' & (pos(' AS ', u) > 0 | pos(' NAMED ', u) > 0 | pos(' TO SEARCH SCOPE ', u) > 0) then id = 'ADD_SEARCH_SCOPE'
  else if left(u, 4) == 'ADD ' then do
    if pos(' TO MY FIND FILE LOCATIONS', u) > 0 | pos(' TO MY FIND FILE LOCATION', u) > 0 then id = 'ADD_FIND_LOCATION'
    else if pos(' TO MY PERMITTED TEMPORARY FILE DIRECTOR', u) > 0 then id = 'ADD_TEMP_DIRECTORY'
  end
  else if left(u, 19) == 'FIND FILES RECEIVED' then id = 'RECENT_FILES'
  else if left(u, 15) == 'WHICH FILE HAS ' then id = 'CONTENT_SEARCH'
  else if pos('LATEST', u) > 0 & pos('CLASS', u) > 0 & pos('FIND', u) == 1 then id = 'LATEST_CLASS'
  else if left(u, 16) == 'CHECK FREE SPACE' then id = 'CHECK_FREE_SPACE'
  else if left(u, 17) == 'CHECK FREE MEMORY' then id = 'CHECK_FREE_MEMORY'
  else if left(u, 15) == 'DEPLOY ZIPFILE ' then id = 'DEPLOY_ZIPFILE'
  else if left(u, 8) == 'CONFIRM ' then id = 'CONFIRM_ACTION'
  else if u == 'RUN TESTS' | u == 'RUN THE TESTS' then id = 'RUN_TESTS'
  else if u == 'REXXPATH' | u == 'SHOW REXXPATH' then id = 'REXXPATH_SHOW'
  else if u == 'SET UP THE REXXPATH' | u == 'SET UP REXXPATH' | u == 'REXXPATH SETUP' then id = 'REXXPATH_SETUP'
  else if left(u, 12) == 'LOG ME INTO ' | left(u, 6) == 'LOGIN ' then do
    if sshAvailable then id = 'SSH_LOGIN'
  end
  else if pos('FIREWALL', u) > 0 & (pos('FIX', u) == 1 | pos('REPAIR', u) == 1 | pos('DIAGNOSE', u) == 1) then id = 'FIREWALL_REPAIR'
  if id == '' then return .Array~new
  p = .IntentionProposal~new(id, 100, 'COMPUTER.WORKSTATION', .true, 'explicit Computer utterance')
  p~putSlot('UTTERANCE', utterance)
  plan = .IntentionPlan~new(id, 'Execute Computer ' || id || ' through scoped adapter')
  select
    when id == 'SSH_LOGIN' then plan~sideEffectClass = 'SESSION'
    when id == 'FIND_DIRECTORIES' | id == 'CHECK_FREE_SPACE' | id == 'CHECK_FREE_MEMORY' | id == 'FILE_INTEGRITY' | id == 'INSTRUCTIONS' | id == 'SEARCH_SCOPES' | id == 'SEARCH_NAMED' | id == 'READ_DOCUMENT' then plan~sideEffectClass = 'READ_ONLY'
    when id == 'RUN_TESTS' then plan~sideEffectClass = 'LOCAL_TEST_EXECUTION'
    when id == 'GITHUB' then plan~sideEffectClass = 'GIT_GOVERNED'
    when id == 'JOBS' then plan~sideEffectClass = 'JOB_GOVERNED'
    when id == 'DEPLOY_ZIPFILE' then plan~sideEffectClass = 'TRANSFER_PREVIEW'
    when id == 'CONFIRM_ACTION' then plan~sideEffectClass = 'CONFIRMED_TRANSFER'
    when id == 'FIREWALL_REPAIR' then do
      plan~sideEffectClass = 'ADMINISTRATIVE'
      plan~requireAuthority('FIREWALL_CHANGE')
    end
    when id == 'ADD_FIND_LOCATION' | id == 'ADD_TEMP_DIRECTORY' | id == 'ADD_SEARCH_SCOPE' | id == 'LEARN' | id == 'REXXPATH_SETUP' then plan~sideEffectClass = 'LOCAL_CONFIGURATION'
    otherwise plan~sideEffectClass = 'READ_ONLY'
  end
  p~proposedPlan(plan)
  return .Array~of(p)

::class ComputerExecution public
::method init
  expose root
  use arg root
::method invoke
  expose root
  use arg decision
  id = decision~registration~id
  raw = decision~slots~at('UTTERANCE')~value
  /* c2x gives a strict hexadecimal shell argument; no raw user content ever
     reaches a shell and Python uses subprocess argument arrays for effectful work. */
  encoded = c2x(raw)
  backend = root || '/src/ComputerActions.py'
  exe = value('COMPUTER_PYTHON',, 'ENVIRONMENT')
  if exe == '' then exe = 'python3'
  command = self~shellQuote(exe) || ' ' || self~shellQuote(backend) || ' --intent ' || id || ' --hex ' || encoded
  address command command
  return rc
::method shellQuote private
  use arg value
  /* Installation path is quoted, including embedded single quotes. */
  escape = "'" || '"' || "'" || '"' || "'"
  return "'" || changestr("'", value, escape) || "'"
::requires 'IntentionService.cls'
