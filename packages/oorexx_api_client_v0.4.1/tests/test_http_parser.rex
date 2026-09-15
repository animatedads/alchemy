raw='HTTP/1.1 200 OK' || '0d0a'x || 'Content-Type: text/plain' || '0d0a'x || 'Content-Length: 5' || '0d0a0d0a'x || 'hello'
h=.ApiHttpParser~parseHead(raw)
if h==.nil then exit 2
if h~status<>200 then exit 3
if h~bodyPrefix<>'hello' then exit 4
chunked='5' || '0d0a'x || 'hello' || '0d0a'x || '0' || '0d0a0d0a'x
if .ApiHttpParser~decodeChunked(chunked)<>'hello' then exit 5
e=.ApiSseParser~parse('event: complete' || '0a'x || 'data: ["ok"]' || '0a0a'x)
if e~items<>1 then exit 6
if e[1]~event<>'complete' | e[1]~data<>'["ok"]' then exit 7
u=.ApiUrl~new('https://example.com:8443/a?q=1')
if u~host<>'example.com' | u~port<>8443 | u~target<>'/a?q=1' then exit 8
say 'PASS HTTP PARSER SSE URL'
::requires '../src/ApiHttpTransport.cls'
