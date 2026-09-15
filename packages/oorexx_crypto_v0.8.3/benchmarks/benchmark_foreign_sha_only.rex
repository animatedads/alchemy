parse arg bridge
installed=.CryptoForeignRuntimeInstaller~install(bridge)
sizes=.array~of(16,1024,4096,16384,1048576)
say 'algorithm bytes loops foreign_ms MiB_per_s provider'
do algorithm over .array~of('SHA256','SHA512')
  do size over sizes
    data='a'~copies(size-4)||'00ff007f'x
    loops=1000
    if size>=16384 then loops=300
    if size>=1048576 then loops=20
    /* warmup */
    if algorithm='SHA256' then drop=.SHA256~new(data)~digest
    else drop=.SHA512~new(data)~digest
    call time 'R'
    do i=1 to loops
      if algorithm='SHA256' then digest=.SHA256~new(data)~digest
      else digest=.SHA512~new(data)~digest
    end
    ms=time('E')*1000/loops
    mib=(size/1048576)/(ms/1000)
    e=.RuntimeImplementationSwitch~broker~lastEvidence
    if e~outcomeCode<>'COMPLETED' | e~providerId<>'foreign.openssl.crypto' then raise syntax 88.900 array('provider evidence mismatch')
    say algorithm size loops ms~format(,4) mib~format(,2) e~providerId
  end
end
installed['target']~close
.RuntimeImplementationSwitch~reset
say 'PASS Foreign Runtime SHA accelerated-only benchmark'
::requires 'CryptoForeignRuntimeProvider.cls'
