::class Store public
::method decide
  result = db~exec("UPDATE decisions SET result = ? WHERE IDEMPOTENCY_KEY = ?")
  return result
