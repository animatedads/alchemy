people=.array~of(.Person~new(1,"Ada",10),.Person~new(2,"Grace",10),.Person~new(3,"Alan",20))
depts=.array~of(.Dept~new(10,"Research"),.Dept~new(20,"Engineering"))

pm=.ObjectTableMapping~new("people")
ignore=pm~column("id","INTEGER","id")
ignore=pm~column("name","VARCHAR","name")
ignore=pm~column("dept_id","INTEGER","deptId")
ignore=pm~identity("id")

dm=.ObjectTableMapping~new("dept")
ignore=dm~column("id","INTEGER","id")
ignore=dm~column("dept_name","VARCHAR","deptName")
ignore=dm~identity("id")

engine=.ObjectDatabaseEngine~new
call assert engine~register("people",people,pm),"people register"
call assert engine~register("dept",depts,dm),"dept register"
sql=.NoSQLServerSQL~new(engine)

r=sql~execute("SELECT people.name,dept.dept_name FROM people JOIN dept ON people.dept_id=dept.id ORDER BY people.name")
call assert r~status=.Error~SUCCESS,"join status"
call assert r~rows~items=3,"join rows"
call assert r~rows[1]["people.name"]="Ada","join first"
call assert r~rows[1]["dept.dept_name"]="Research","join dept"
call assert r~rows[3]["people.name"]="Grace","join order"

r=sql~execute("SELECT dept.dept_name,COUNT(*) AS n FROM people JOIN dept ON people.dept_id=dept.id GROUP BY dept.dept_name ORDER BY dept.dept_name")
call assert r~status=.Error~SUCCESS,"aggregate status"
call assert r~rows~items=2,"aggregate groups"
call assert r~rows[1]["dept.dept_name"]="Engineering","aggregate first group"
call assert r~rows[1]["n"]=1,"engineering count"
call assert r~rows[2]["dept.dept_name"]="Research","aggregate second group"
call assert r~rows[2]["n"]=2,"research count"

call assert engine~version~supports("OBJECT_TABLE_JOIN"),"join capability"
call assert engine~version~supports("OBJECT_TABLE_AGGREGATE"),"aggregate capability"
say "NOSQLSERVER V0.53 OBJECT JOIN / AGGREGATE SMOKE: OK"
exit 0

assert: procedure
 use arg condition,message
 if \condition then do
  say "ASSERT FAILED:" message
  exit 1
 end
 return

::class Person
::attribute id
::attribute name
::attribute deptId
::method init
 use arg id,name,deptId
 self~id=id; self~name=name; self~deptId=deptId

::class Dept
::attribute id
::attribute deptName
::method init
 use arg id,deptName
 self~id=id; self~deptName=deptName

::requires "../src/NoSQLServer.cls"
