/* Deterministic test-only BSF/JMS stand-in.  It models only the methods used by
 * test_federationbank_bsf_edge.rex; it is never placed on the production path. */

::routine "BSF.IMPORTCLASS" public
  use arg name
  select
    when name = "java.util.Hashtable" then return .FakeJavaHashtable
    when name = "javax.naming.InitialContext" then return .FakeInitialContext
    otherwise raise syntax 88.900 array("FAKE_BSF_CLASS_NOT_AVAILABLE:" || name)
  end

::class FakeJavaHashtable public
::method init
  expose values
  values = .directory~new
::method put
  expose values
  use arg name, value
  values[name~string] = value
  return value
::method at
  expose values
  use arg name
  return values[name~string]

::class FakeInitialContext public
::method init
  use arg environment = .nil
::method lookup
  use arg name
  if name~string = "CF" then return .FakeConnectionFactory~new
  return .FakeDestination~new(name)
::method close
  return .true

::class FakeDestination public
::attribute name get
::method init
  expose name
  use arg name
  name = name~string
::method string
  expose name
  return name

::class FakeConnectionFactory public
::method createConnection
  use arg username = "", password = ""
  c = .FakeConnection~new
  .environment["FAKE_JMS_CONNECTION"] = c
  return c

::class FakeConnection public
::attribute started get
::method init
  expose started
  started = .false
::method createSession
  use arg transacted, acknowledgeMode
  s = .FakeSession~new(transacted, acknowledgeMode)
  .environment["FAKE_JMS_SESSION"] = s
  return s
::method start
  expose started
  started = .true
  return .true
::method "BSF.INVOKE"
  use arg methodName
  if methodName~string~translate = "START" then return self~start
  raise syntax 88.900 array("FAKE_BSF_METHOD_NOT_AVAILABLE:" || methodName)
::method close
  return .true

::class FakeSession public
::attribute transacted get
::attribute acknowledgeMode get
::attribute commits get
::attribute rollbacks get
::attribute recoveries get
::method init
  expose transacted acknowledgeMode commits rollbacks recoveries
  use arg transacted, acknowledgeMode
  transacted = transacted
  acknowledgeMode = acknowledgeMode
  commits = 0
  rollbacks = 0
  recoveries = 0
::method createConsumer
  use arg destination
  c = .FakeConsumer~new(destination)
  .environment["FAKE_JMS_CONSUMER"] = c
  return c
::method createProducer
  use arg destination
  p = .FakeProducer~new(destination)
  .environment["FAKE_JMS_PRODUCER"] = p
  return p
::method createTextMessage
  use arg text
  return .FakeTextMessage~new(text)
::method createMapMessage
  return .FakeMapMessage~new
::method commit
  expose commits
  commits += 1
  return .true
::method rollback
  expose rollbacks
  rollbacks += 1
  return .true
::method recover
  expose recoveries
  recoveries += 1
  return .true
::method close
  return .true

::class FakeConsumer public
::attribute destination get
::method init
  expose destination
  use arg destination
  destination = destination
::method receive
  use arg timeoutMs = 0
  if .environment~hasIndex("FAKE_JMS_INBOUND") then do
    m = .environment["FAKE_JMS_INBOUND"]
    .environment~remove("FAKE_JMS_INBOUND")
    return m
  end
  return .nil
::method close
  return .true

::class FakeProducer public
::attribute destination get
::attribute sends get
::attribute lastMessage get
::method init
  expose destination sends lastMessage
  use arg destination
  destination = destination
  sends = 0
  lastMessage = .nil
::method send
  expose sends lastMessage
  use arg message
  sends += 1
  lastMessage = message
  return .true
::method "BSF.INVOKE"
  use arg methodName, message = .nil
  if methodName~string~translate = "SEND" then return self~send(message)
  raise syntax 88.900 array("FAKE_BSF_METHOD_NOT_AVAILABLE:" || methodName)
::method close
  return .true

::class FakeEnumeration public
::method init
  expose values position
  use arg values
  position = 1
::method hasMoreElements
  expose values position
  return position <= values~items
::method nextElement
  expose values position
  value = values[position]
  position += 1
  return .FakeJavaString~new(value)

::class FakeJavaString public
::method init
  expose value
  use arg value
  value = value~string
::method toString
  expose value
  return value
::method string
  expose value
  return value

::class FakeJMSMessage public
::method init
  expose properties correlationId jmsType messageId timestamp replyTo destination deliveryMode redelivered expiration priority
  properties = .directory~new
  correlationId = ""
  jmsType = ""
  messageId = "ID:FAKE"
  timestamp = 0
  replyTo = ""
  destination = ""
  deliveryMode = 2
  redelivered = .false
  expiration = 0
  priority = 4
::method setStringProperty
  expose properties
  use arg name, value
  properties[name~string] = value~string
  return .true
::method getObjectProperty
  expose properties
  use arg name
  if properties~hasIndex(name~string) then return properties[name~string]
  return .nil
::method getPropertyNames
  expose properties
  return .FakeEnumeration~new(properties~allIndexes)
::method property
  expose properties
  use arg name
  if properties~hasIndex(name~string) then return properties[name~string]
  return .nil
::method setJMSCorrelationID
  expose correlationId
  use arg value
  correlationId = value~string
  return .true
::method getJMSCorrelationID
  expose correlationId
  return correlationId
::method setJMSType
  expose jmsType
  use arg value
  jmsType = value~string
  return .true
::method getJMSType
  expose jmsType
  return jmsType
::method setJMSMessageID
  expose messageId
  use arg value
  messageId = value~string
  return .true
::method getJMSMessageID
  expose messageId
  return messageId
::method getJMSTimestamp
  expose timestamp
  return timestamp
::method getJMSReplyTo
  expose replyTo
  return replyTo
::method getJMSDestination
  expose destination
  return destination
::method getJMSDeliveryMode
  expose deliveryMode
  return deliveryMode
::method getJMSRedelivered
  expose redelivered
  return redelivered
::method getJMSExpiration
  expose expiration
  return expiration
::method getJMSPriority
  expose priority
  return priority
::method acknowledge
  return .true

::class FakeTextMessage subclass FakeJMSMessage public
::method init
  expose text
  use arg text = ""
  self~init:super
  text = text~string
::method getText
  expose text
  return text
::method "BSF.ISA"
  use arg className
  return className~string = "javax.jms.TextMessage"

::class FakeMapMessage subclass FakeJMSMessage public
::method init
  expose values
  self~init:super
  values = .directory~new
::method setString
  expose values
  use arg name, value
  values[name~string] = value~string
  return .true
::method getObject
  expose values
  use arg name
  if values~hasIndex(name~string) then return values[name~string]
  return .nil
::method getMapNames
  expose values
  return .FakeEnumeration~new(values~allIndexes)
::method mapValue
  expose values
  use arg name
  if values~hasIndex(name~string) then return values[name~string]
  return .nil
::method "BSF.ISA"
  use arg className
  return className~string = "javax.jms.MapMessage"
