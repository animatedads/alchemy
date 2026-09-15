call test
say "PASS test_builder_application_composition"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  target=.WireUIBuilderProject~new("VISUAL_TARGET","Neutral visual target")
  br=.WireUIBuilderRuntimeFactory~build(target,.nil,"BUILDER-APP","VISUAL","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder app"
  app=br~value

  d=.directory~new; d["artifactId"]="PANEL"; d["publishVersion"]="1"; d["primitive"]="PANEL"; call must send(app,"component-editor","DESIGN.COMPONENT.DRAFT",d)
  do id over .array~of("A","B")
    d=.directory~new; d["artifactId"]=id; d["publishVersion"]="1"; d["semanticType"]="CARD"; d["fields"]="label"; d["actions"]=""; d["audiencePolicyRef"]="PUBLIC"; call must send(app,"element-editor","DESIGN.ELEMENT.DRAFT",d)
    d=.directory~new; d["artifactId"]=id"_VIEW"; d["publishVersion"]="1"; d["profile"]="HUMAN_VISUAL"; d["elementId"]=id; d["componentId"]="PANEL"; d["definitionId"]=id"_DEF"; d["action"]=""; d["styleRole"]="card"; d["materialRole"]="card"; call must send(app,"projection-editor","DESIGN.PROJECTION.DRAFT",d)
  end
  d=.directory~new; d["artifactId"]="MAIN"; d["publishVersion"]="1"; d["initialState"]="HOME"; d["stateId"]="HOME"; d["active"]="A,B"; d["prefetch"]=""; d["onDemand"]=""; call must send(app,"journey-editor","DESIGN.JOURNEY.DRAFT",d)

  call place app,"A",10
  call place app,"B",20
  layout=target~draft("COMPOSITION","HOME_LAYOUT"); call assert layout<>.nil,"composition draft exists"
  call assert layout~spec["placements"]~items=2,"two visual placements"
  canvas=app~view~instance("composition-canvas"); call assert canvas["slots"]["items"]~items=2,"canvas projected from authoritative target draft"
  aid=canvas["slots"]["items"][1]["id"]; bid=canvas["slots"]["items"][2]["id"]

  d=.directory~new; d["id"]=bid; call must send(app,"composition-canvas","COMPOSITION.SELECT",d)
  editor=app~view~instance("composition-editor"); call assert editor["slots"]["elementId"]="B","canvas selection populates inspector"
  call assert editor["slots"]["span"]="6" | editor["slots"]["span"]=6,"inspector carries layout span"

  before=target~revision
  d=.directory~new; d["sourceId"]=bid; d["targetId"]=aid; call must send(app,"composition-canvas","DESIGN.COMPOSITION.MOVE",d)
  call assert target~revision=before+1,"drag maps to one typed project operation"
  rows=target~draft("COMPOSITION","HOME_LAYOUT")~spec["placements"]
  call assert rows[1]["elementId"]="B" & rows[2]["elementId"]="A","visual move changes semantic placement order"
  call assert target~workspace~allArtifacts~items=0,"visual work still draft only"

  d=.directory~new; d["releaseId"]="VISUAL_TARGET"; d["releaseVersion"]="1"; call must send(app,"publish","DESIGN.PUBLISH",d)
  summary=app~view~instance("preview-summary")
  call assert summary["slots"]["mode"]="PUBLISHED","preview summary switches to compiled release"
  call assert summary["slots"]["journeyState"]="HOME","compiled preview resolves initial state"
  call assert summary["slots"]["compositionCount"]=1,"compiled preview resolves composition"
  call assert summary["slots"]["activeDefinitions"]~pos("A_DEF@1")>0 & summary["slots"]["activeDefinitions"]~pos("B_DEF@1")>0,"compiled preview lists exact active definitions"
  call assert target~workspace~artifact("COMPOSITION","HOME_LAYOUT","1")<>.nil,"composition materialised only at publish"
  return

place:
  use arg app,elementId,order
  d=.directory~new; d["artifactId"]="HOME_LAYOUT"; d["publishVersion"]="1"; d["journeyId"]="MAIN"; d["profile"]="HUMAN_VISUAL"; d["stateId"]="HOME"; d["layoutModel"]="GRID12"; d["elementId"]=elementId; d["projectionId"]=""; d["region"]="main"; d["order"]=order; d["span"]=6; d["rowSpan"]=1; d["align"]="STRETCH"; d["viewportClass"]="DEFAULT"
  call must send(app,"composition-editor","DESIGN.COMPOSITION.DRAFT",d); return

send:
  use arg app,instanceId,action,detail
  f=.directory~new; f["applicationId"]=app~applicationId; f["sessionId"]=app~sessionId; f["accessPointId"]=app~accessPointId; f["viewRef"]=app~view~viewRef; f["elementInstance"]=instanceId; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=detail
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderApplication.cls"
