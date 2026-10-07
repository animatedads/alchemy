q=.HttpsConnectionQueue~new(4)

do i=1 to 4
  if \q~add(.array~of(i)) then do
    say 'FAIL queue rejected item' i
    exit 1
  end
end
if q~add(.array~of(5)) then do
  say 'FAIL queue accepted over capacity'
  exit 1
end
if q~accepted<>4 | q~rejected<>1 | q~highWaterMark<>4 | q~pendingCount<>4 then do
  say 'FAIL queue telemetry accepted='q~accepted 'rejected='q~rejected 'high='q~highWaterMark 'pending='q~pendingCount
  exit 1
end

do i=1 to 4
  item=q~next
  if item==.nil | item==.false | item[1]<>i then do
    say 'FAIL FIFO order expected='i
    exit 1
  end
end
if q~next<>.nil then do
  say 'FAIL active empty queue did not return .nil'
  exit 1
end
q~stop
if q~next<>.false then do
  say 'FAIL stopped empty queue did not return .false'
  exit 1
end

say 'PASS bounded accepted-connection FIFO capacity=4 highWater=4 rejected=1'
exit 0

::requires 'https_server.cls'
