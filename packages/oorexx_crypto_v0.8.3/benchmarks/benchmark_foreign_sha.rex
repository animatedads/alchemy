parse arg bridge
if bridge='' then raise syntax 88.900 array('bridge path required')
installed=.CryptoForeignRuntimeInstaller~install(bridge)
sizes=.array~of(16,1024,4096)
say 'algorithm bytes native_ms foreign_ms speedup provider'
do algorithm over .array~of('SHA256','SHA512')
  do size over sizes
    data='a'~copies(size)
    .CryptoLibraryBuild~referenceSwitch=.nil
    call time 'R'
    if algorithm='SHA256' then native=.SHA256~new(data)~digest
    else native=.SHA512~new(data)~digest
    nativeMs=time('E')*1000

    .CryptoLibraryBuild~referenceSwitch=.RuntimeImplementationSwitch
    loops=1000
    if size>=4096 then loops=300
    if algorithm='SHA256' then warm=.SHA256~new(data)~digest
    else warm=.SHA512~new(data)~digest
    call time 'R'
    do i=1 to loops
      if algorithm='SHA256' then accelerated=.SHA256~new(data)~digest
      else accelerated=.SHA512~new(data)~digest
    end
    foreignMs=time('E')*1000/loops
    if accelerated<>native then raise syntax 88.900 array('digest mismatch '||algorithm||' '||size)
    e=.RuntimeImplementationSwitch~broker~lastEvidence
    if e~outcomeCode<>'COMPLETED' | e~providerId<>'foreign.openssl.crypto' then raise syntax 88.900 array('provider evidence mismatch '||algorithm||' '||size)
    say algorithm size nativeMs~format(,3) foreignMs~format(,4) (nativeMs/foreignMs)~format(,2) e~providerId
  end
end
installed['target']~close
.RuntimeImplementationSwitch~reset
say 'PASS Foreign Runtime SHA native comparison benchmark'
::requires 'CryptoForeignRuntimeProvider.cls'
