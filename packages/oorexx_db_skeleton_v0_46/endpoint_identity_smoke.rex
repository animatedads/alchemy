my = .MySQLEngine~new
rows = .array~new
row = .DatabaseRow~new
row~put("__oorexx_server_version", "5.7.44-NoSQLServer-ooRexx")
rows~append(row)
cols = .array~of("__oorexx_server_version")
qr = .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, cols, rows)

id = my~parseEndpointIdentity(qr)
call assert (id~protocol = "mysql"), "protocol"
call assert (id~product = "nosqlserver"), "nosqlserver product"
call assert (id~rawVersion = "5.7.44-NoSQLServer-ooRexx"), "raw version"

row2 = .DatabaseRow~new
row2~put("__oorexx_server_version", "11.4.2-MariaDB")
qr2 = .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, cols, .array~of(row2))
id2 = my~parseEndpointIdentity(qr2)
call assert (id2~product = "mariadb"), "mariadb product"

say "DATABASE ENDPOINT IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
