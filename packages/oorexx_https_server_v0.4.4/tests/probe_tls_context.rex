parse source . . here
root=filespec('D',here)||filespec('P',here)'..'
ri=.foreign~runtimeInfo
tls=.foreign~load(root'/bridge/openssl_tls.bridge.json')
method=tls~tls_server_method
if method==.nil then do; say 'FAIL TLS_server_method'; exit 1; end
ctx=tls~ctx_new(method)
if ctx==.nil then do; say 'FAIL SSL_CTX_new'; exit 1; end
if ri~maxArity=0 then do
  ctl=tls~ctx_ctrl(ctx,123,771,.nil)
  if ctl<>1 then do; say 'FAIL SSL_CTX_ctrl min protocol'; exit 1; end
  opts=tls~ctx_set_options(ctx,1073741824)
  policy='min-proto-control'
end
else do
  opts=tls~ctx_set_options(ctx,1409286144)
  policy='options-fallback'
end
say 'TLS_PROVIDER' tls~providerPath
say 'TLS_OPTIONS' opts
say 'THREADING' tls~threadingMode
say 'FOREIGN_RUNTIME' ri~runtimeVersion 'DISPATCHER' ri~nativeDispatcher 'MAX_ARITY' ri~maxArity 'POLICY' policy
ctx~close
method~close
tls~close
say 'PASS tls context probe'
exit 0
::requires 'foreign.cls'
