package org.alchemy.wireui.swing;

import javax.swing.Timer;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Presentation fixture for the Java/Swing NotNotes surface. Business truth remains outside the renderer. */
final class NotNotesSwingDemo {
    private NotNotesSwingDemo() {}

    static WireSwingRuntime createRuntime() {
        WireSwingRuntime runtime = WireSwingRuntime.create();
        runtime.hello("notnotes-swing-demo", "local", "desktop");
        installDefinitions(runtime);
        runtime.accept(snapshot(1));
        return runtime;
    }

    static Timer startAuthorityLoop(WireSwingRuntime runtime) {
        Timer timer = new Timer(40, e -> {
            Map<String,Object> action;
            while ((action = runtime.pollAction()) != null) {
                String name = WireValues.text(action, "action", "");
                if (name.equals("NOTNOTES.ASK")) {
                    runtime.accept(statusPatch(runtime.revision()+1, "Help Desk ready · intention accepted for application authority"));
                } else if (name.equals("NOTNOTES.DOCUMENT.OPEN")) {
                    runtime.accept(statusPatch(runtime.revision()+1, "Selected document projected by stable NotNotes identity"));
                }
            }
        });
        timer.setRepeats(true);
        timer.start();
        return timer;
    }

    private static void installDefinitions(WireSwingRuntime r) {
        r.accept(def("ROOT","PANEL","","","root-panel",Map.of(),place(0,12)));
        r.accept(def("TITLE","TEXT","","","hero-title",Map.of(),place(0,8)));
        r.accept(def("SUBTITLE","TEXT","","","muted",Map.of(),place(1,4)));
        r.accept(def("NAV","LIST","NOTNOTES.NAVIGATE","","navigation card",Map.of(),place(10,2)));
        r.accept(def("DOCS","SEMANTIC_COLLECTION","NOTNOTES.DOCUMENT.OPEN","","document-list card",Map.of(),place(11,6)));
        r.accept(def("DETAIL","SEMANTIC_RECORD","","Document","detail-card",bindings(
                "Status","status","Type","type","Owner","owner","Updated","updated","Relationships","relationships","Summary","summary"),place(12,4)));
        r.accept(def("COMPOSER","SEMANTIC_RECORD","NOTNOTES.ASK","Ask notNotes","composer-card",bindings("message","message"),place(20,12)));
        r.accept(def("STATUS","STATUS","","","muted status",Map.of(),place(30,12)));
    }

    private static Map<String,Object> snapshot(long rev) {
        return msg("UI_VIEW_SNAPSHOT", Map.of(
                "viewRef","NOTNOTES.HOME", "revision",rev, "rootInstanceId","root",
                "instances", List.of(
                        inst("root","ROOT@1","",Map.of()),
                        inst("title","TITLE@1","root",Map.of("text","notNotes")),
                        inst("subtitle","SUBTITLE@1","root",Map.of("text","Documents · Reports · Intentions")),
                        inst("nav","NAV@1","root",Map.of("items",List.of("Home","Documents","TPS Reports","Approvals","Reports","Help Desk"))),
                        inst("docs","DOCS@1","root",Map.of(
                                "items",List.of(
                                        doc("TR-0014","TPS-2026-014","PENDING APPROVAL"),
                                        doc("ARC-0041","Architecture review","APPROVED"),
                                        doc("SEC-2007","Security assessment","DRAFT"),
                                        doc("REL-3021","Release authority","PENDING APPROVAL"),
                                        doc("FIN-1088","Quarterly controls","APPROVED"),
                                        doc("OPS-0092","Service continuity review","DRAFT"),
                                        doc("TPS-0172","TPS Report","APPROVED")
                                ),
                                "rangeWindow",Map.of("start",0,"count",7,"total",52))),
                        inst("detail","DETAIL@1","root",Map.of(
                                "status","Pending approval",
                                "type","TPS Report",
                                "owner","Fred",
                                "updated","Today, 12:18",
                                "relationships","Project Alchemy · Review-17 · 3 linked documents",
                                "summary","Management review for the current delivery set.")),
                        inst("composer","COMPOSER@1","root",Map.of("message","")),
                        inst("status","STATUS@1","root",Map.of("text","52 documents · 12 TPS reports · 6 saved reports · semantic authority: notNotes"))
                )));
    }

    private static Map<String,Object> statusPatch(long rev, String text) {
        return msg("UI_VIEW_PATCH", Map.of("viewRef","NOTNOTES.HOME","fromRevision",rev-1,"toRevision",rev,
                "ops",List.of(Map.of("op","SET_SLOT","instanceId","status","slot","text","value",text))));
    }

    private static Map<String,Object> doc(String id,String label,String status) {
        return Map.of("id",id,"label",label,"status",status);
    }
    private static Map<String,Object> bindings(String... p) {
        Map<String,Object> m=new LinkedHashMap<>(); for(int i=0;i<p.length;i+=2)m.put(p[i],p[i+1]); return m;
    }
    private static Map<String,Object> def(String id,String primitive,String action,String label,String role,Map<String,Object> bindings,Map<String,Object> placement) {
        Map<String,Object> f=new LinkedHashMap<>();
        f.put("definitionId",id); f.put("definitionVersion",1); f.put("definitionKey",id+"@1"); f.put("primitive",primitive);
        f.put("action",action); f.put("label",label); f.put("styleRole",role); f.put("profile","HUMAN_VISUAL"); f.put("bindings",bindings);
        f.put("contentAddress","notnotes-demo:"+id); f.put("metadata",Map.of("compositionHints",List.of(Map.of("layoutModel","GRID12","placement",placement))));
        return msg("UI_DEFINITION",f);
    }
    private static Map<String,Object> place(int order,int span) { return Map.of("elementId","notnotes","region","main","order",order,"span",span,"rowSpan",1,"align","STRETCH","viewportClass","DEFAULT"); }
    private static Map<String,Object> inst(String id,String key,String parent,Map<String,Object> slots) { return Map.of("instanceId",id,"definitionKey",key,"parentId",parent,"slots",slots); }
    private static Map<String,Object> msg(String type,Map<String,Object> fields) { Map<String,Object> m=new LinkedHashMap<>(); m.put("type",type); m.put("protocolVersion",WireSwingProtocol.VERSION); m.putAll(fields); return m; }
}
