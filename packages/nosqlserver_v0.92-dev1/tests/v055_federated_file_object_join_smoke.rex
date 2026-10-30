root=.NoSQLServerTestSupport~createBlankDatabase("v055")
file=.FileDatabaseEngine~new(root)
filesql=.NoSQLServerSQL~new(file)
call ok filesql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR)")
call ok filesql~execute("INSERT INTO customer VALUES (1,'Ada'),(2,'Grace'),(3,'Alan')")

sensors=.array~of(.Sensor~new(101,1,82),.Sensor~new(102,1,71),.Sensor~new(103,2,91),.Sensor~new(104,99,99))
sm=.ObjectTableMapping~new("sensors")
ignore=sm~column("sensor_id","INTEGER","sensorId")
ignore=sm~column("customer_id","INTEGER","customerId")
ignore=sm~column("temperature","INTEGER","temperature","temperature=")
ignore=sm~identity("sensor_id")

engine=.FederatedDatabaseEngine~new(root)
call assert engine~register("sensors",sensors,sm),"sensor register"
sql=.NoSQLServerSQL~new(engine)

r=sql~execute("SELECT customer.name,sensors.temperature FROM customer JOIN sensors ON customer.customer_id=sensors.customer_id WHERE sensors.temperature > 80 ORDER BY customer.name")
call assert r~status=.Error~SUCCESS,"federated join status"
call assert r~rows~items=2,"federated join count"
call assert r~rows[1]["customer.name"]="Ada","federated Ada"
call assert r~rows[1]["sensors.temperature"]=82,"Ada temperature"
call assert r~rows[2]["customer.name"]="Grace","federated Grace"
call assert r~rows[2]["sensors.temperature"]=91,"Grace temperature"

-- Both sides remain their original storage kinds.
call assert engine~fileEngine~table("customer") \== .nil,"file table still file backed"
call assert engine~objectEngine~table("sensors") \== .nil,"sensor table live object backed"
call assert engine~version~engine="FEDERATED","federated version"
call assert engine~version~supports("FEDERATED_CATALOG"),"catalog capability"
call assert engine~version~supports("FILE_OBJECT_JOIN"),"file object join capability"
call assert \engine~version~supports("TRANSACTIONS"),"mixed catalog does not advertise transactions"
tx=engine~transaction
tr=tx~commit
call assert tr~error=.Error~SQLUNSUPPORTED,"federated transaction cleanly unsupported"

-- Object update remains routed to the live setter inside federation.
r=sql~execute("UPDATE sensors SET temperature=75 WHERE sensor_id=101")
call assert r~status=.Error~SUCCESS,"federated object update"
call assert sensors[1]~temperature=75,"federated setter side effect"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.55 FEDERATED FILE/OBJECT JOIN SMOKE: OK"
exit 0

ok: procedure
 use arg rs
 call assert rs~status=.Error~SUCCESS,"setup"
 return
assert: procedure
 use arg condition,message
 if \condition then do; say "ASSERT FAILED:" message; exit 1; end
 return

::class Sensor
::attribute sensorId
::attribute customerId
::attribute temperature
::method init
 use arg sensorId,customerId,temperature
 self~sensorId=sensorId; self~customerId=customerId; self~temperature=temperature

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
