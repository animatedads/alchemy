codec = .Compress~new
payload = 'bootstrap bootstrap bootstrap'
gz = codec~gzip(payload, 'FIXED')
say 'provider=' codec~provider
say 'input=' length(payload) 'gzip=' length(gz)
say 'roundtrip=' (codec~gunzip(gz) == payload)
::requires '../src/Compress.cls'
