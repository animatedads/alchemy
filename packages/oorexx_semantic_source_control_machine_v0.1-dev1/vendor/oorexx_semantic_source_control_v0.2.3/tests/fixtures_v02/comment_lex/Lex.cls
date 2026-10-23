/*
 ::options digits 9
 ::requires "Fake.cls"
 ::class Fake public
 ::method phantom; return 999
 /* nested fake directive: ::requires "NestedFake.cls" */
*/
::options digits 30
::class Real public
::method ping; return 1
::requires "RealDep.cls"
