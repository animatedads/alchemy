/******************************************************************************/
/* Queue Fabric evidence. Does not ::requires ObjectQueueFabric.cls.          */
/* Queues remain the work primitive; this file only names them.               */
/******************************************************************************/
::class ReportQueueAdapter public subclass ReportAdapterBase

::method transformId class
  return "queue.fabric.queue/0.9"

::method bind class
  use arg bindingId, role, d
  self~need(d, "queue")
  mgr = self~opt(d, "manager", "")
  if mgr = "" then point = "QUEUE:" || d["queue"]
  else point = "QUEUE:" || mgr || "/" || d["queue"]
  span = self~opt(d, "span", "")
  if span = "" then do
     bits = ""
     do key over .array~of("ready", "inflight", "total", "capacity")
        if d~hasIndex(key), d[key] \= .nil, d[key] \= "" then
           bits = bits || key || "=" || d[key] || " "
     end
     span = bits~strip
  end
  return .ReportBinding~new(bindingId, role, "QUEUE", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportQueueWorkAdapter public subclass ReportAdapterBase

::method transformId class
  return "queue.fabric.work/0.9"

::method bind class
  use arg bindingId, role, d
  self~need(d, "correlationId")
  point = "QUEUEWORK:" || d["correlationId"]
  span = self~opt(d, "span", "")
  if span = "" then do
     seq = self~opt(d, "deliverySequence", "")
     pri = self~opt(d, "priority", "")
     bits = ""
     if seq \= "" then bits = "deliverySequence=" || seq
     if pri \= "" then bits = bits || " priority=" || pri
     span = bits~strip
  end
  return .ReportBinding~new(bindingId, role, "QUEUE_WORK", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportQueueDispositionAdapter public subclass ReportAdapterBase
/* ACK / NACK / BACKOUT / DEAD_LETTER / EXPIRE / RELEASE */

::method transformId class
  return "queue.fabric.disposition/0.9"

::method bind class
  use arg bindingId, role, d
  self~need(d, "disposition")
  self~need(d, "correlationId")
  disp = d["disposition"]~string~upper
  point = "QUEUEDISP:" || disp || ":" || d["correlationId"]
  return .ReportBinding~new(bindingId, role, "QUEUE_DISPOSITION", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportQueueUowAdapter public subclass ReportAdapterBase

::method transformId class
  return "queue.fabric.uow/0.9"

::method bind class
  use arg bindingId, role, d
  self~need(d, "uowId")
  point = "QUEUEUOW:" || d["uowId"]
  span = self~opt(d, "span", "")
  if span = "" then span = self~opt(d, "result", "")
  return .ReportBinding~new(bindingId, role, "QUEUE_UOW", point,,
        self~opt(d, "digest", ""), span,,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))


::class ReportQueueJournalAdapter public subclass ReportAdapterBase

::method transformId class
  return "queue.fabric.journal/0.9"

::method bind class
  use arg bindingId, role, d
  self~need(d, "recordId")
  point = "QUEUEJOURNAL:" || d["recordId"]
  return .ReportBinding~new(bindingId, role, "QUEUE_JOURNAL", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))

::requires "../ReportAdapterBase.cls"
