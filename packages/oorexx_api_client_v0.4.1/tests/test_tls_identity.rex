parse arg bridgeDir caFile
cfg=.ApiHttpTransportConfig~new; cfg~bridgeDirectory=bridgeDir; cfg~caFile=caFile; cfg~readTimeout=5; cfg~writeTimeout=5
transport=.ApiHttpsTransport~new(cfg)
r=.ApiRequest~new('badhost','GET','https://127.0.0.1:18443/hello')
resp=transport~execute(r)
transport~close
if resp~ok then do; say 'FAIL hostname mismatch accepted'; exit 2; end
if resp~errorCode<>'TLS_HANDSHAKE_FAILED' then do; say 'FAIL wrong error' resp~errorCode; exit 3; end
say 'PASS TLS HOSTNAME MISMATCH FAILS CLOSED'
::requires 'ApiHttpTransport.cls'
