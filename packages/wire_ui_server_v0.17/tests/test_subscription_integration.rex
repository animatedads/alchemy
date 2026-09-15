/* Definition delivery is Queue Fabric subscription wiring, distinct from direct live queues. */
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
topics = .QueueTopicFabric~new(manager)
server = .WireUIServer~new(manager, topics, "admin")
view = .WireUIView~new("V", "root")
slots=.table~new
call must view~createInstance("root","PANEL@1",slots), "instance"
app = .WireUIApplication~new("APP-S", "SESSION-S", "AP-S", view, .WireUIProjection~new)
call must app~registerDefinition(.WireUIElementDefinition~new("PANEL","1","PANEL")), "panel def"
call must app~registerDefinition(.WireUIElementDefinition~new("CHAT","1","ACTION_BUTTON","CHAT.OPEN")), "chat def"
call must app~registerDefinition(.WireUIElementDefinition~new("UNUSED","1","TEXT")), "unused def"
base=.WireUISubscription~new("BASE","1","base view","policy:base"); base~addDefinition("PANEL@1"); base~activate; app~addSubscription(base)
chat=.WireUISubscription~new("CHATCTX","1","chat view","policy:chat"); chat~addDefinition("CHAT@1"); app~addSubscription(chat)
server~registerApplication(app)
call must server~provisionDefinitionSubscription("AP-S","browser"), "definition channel"
call must server~publishRequiredDefinitions("APP-S"), "publish base"
q="WIREUI.DEF.AP-S"
call expect manager~depth(q,"browser")~value["ready"] = 1, "only active PANEL definition delivered"
pkg=manager~claim(q,"browser")~value
call expect pkg~payload["definitionId"] = "PANEL", "subscription delivered PANEL"
call must manager~ack(q,pkg~packageId,pkg~claimToken,"browser"), "ack panel"
ignore=app~activateSubscription("CHATCTX")
call must server~publishRequiredDefinitions("APP-S"), "publish chat state"
/* PANEL is republished because no cache manifest was supplied; CHAT is newly wired. */
call expect manager~depth(q,"browser")~value["ready"] = 2, "active subscriptions deliver PANEL plus CHAT"
seenChat=.false; seenUnused=.false
do while manager~depth(q,"browser")~value["ready"] > 0
  x=manager~claim(q,"browser")~value
  if x~payload["definitionId"] = "CHAT" then seenChat=.true
  if x~payload["definitionId"] = "UNUSED" then seenUnused=.true
  call must manager~ack(q,x~packageId,x~claimToken,"browser"), "ack"
end
call expect seenChat & \seenUnused, "new subscribed definition delivered; unsubscribed definition absent"
say "PASS subscription integration"
exit 0
must: procedure
 use arg r,l
 if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
 return
expect: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 say "ok" l
 return
::requires "WireUIAll.cls"
::requires "WireUIServer.cls"
