/* Fixture: SELECT identity. a3 and a7 test one variable against strings (3 and 7 arms): one node.
   b tests a number range: a different node. Never executed. */
::routine a3
  use arg x
  select
    when x = 'a' then return 1
    when x = 'b' then return 2
    otherwise return 0
  end
::routine a7
  use arg y
  select
    when y = 'p' then return 1
    when y = 'q' then return 2
    when y = 'r' then return 3
    when y = 's' then return 4
    when y = 't' then return 5
    when y = 'u' then return 6
    otherwise return 0
  end
::routine b
  use arg n
  select
    when n < 0 then return 'negative'
    when n > 100 then return 'large'
    otherwise return 'ok'
  end
