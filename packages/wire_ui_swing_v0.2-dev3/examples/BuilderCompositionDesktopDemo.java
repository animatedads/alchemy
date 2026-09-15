import org.alchemy.wireui.swing.WireSwingDesktopWindow;
import org.alchemy.wireui.swing.WireSwingRuntime;

import javax.imageio.ImageIO;
import javax.swing.UIManager;
import java.io.File;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class BuilderCompositionDesktopDemo {
    public static void main(String[] args) throws Exception {
        if (args.length != 1) throw new IllegalArgumentException("usage: BuilderCompositionDesktopDemo <output.png>");
        UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());

        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.hello("builder-preview", "demo", "desktop");

        runtime.accept(def("ROOT", "PANEL", "", Map.of(), placement(0, 12)));
        runtime.accept(def("APP_HEADER", "TEXT", "", Map.of(), placement(10, 12)));
        runtime.accept(def("NAVIGATION", "LIST", "", Map.of(), placement(20, 3)));
        runtime.accept(def("SEARCH_PANEL", "FORM", "FLIGHT.SEARCH",
                Map.of("origin", "origin", "destination", "destination", "date", "date", "passengers", "passengers"), placement(30, 5)));
        runtime.accept(def("DETAIL_PANEL", "SEMANTIC_RECORD", "",
                Map.of("status", "status", "route", "route", "fare", "fare"), placement(40, 4)));
        runtime.accept(def("NOTICES", "STATUS", "", Map.of(), placement(50, 12)));

        runtime.accept(message("UI_VIEW_SNAPSHOT", Map.of(
                "viewRef", "SEARCH", "revision", 0, "rootInstanceId", "root",
                "instances", List.of(
                        inst("root", "ROOT@1", "", Map.of()),
                        inst("header", "APP_HEADER@1", "root", Map.of("text", "Federation Air — Search")),
                        inst("nav", "NAVIGATION@1", "root", Map.of("items", List.of("Search", "Bookings", "Customers", "Operations"))),
                        inst("search", "SEARCH_PANEL@1", "root", Map.of("origin", "PIK", "destination", "EWR", "date", "2026-09-01", "passengers", "2")),
                        inst("detail", "DETAIL_PANEL@1", "root", Map.of("status", "Ready", "route", "PIK → EWR", "fare", "GBP 199.00")),
                        inst("notices", "NOTICES@1", "root", Map.of("text", "Wire UI Builder GRID12 • Swing renderer v0.2-dev3"))))));

        try (WireSwingDesktopWindow window = WireSwingDesktopWindow.create(runtime, "Wire UI — Swing Desktop Preview", 1100, 650)) {
            window.showWindow();
            ImageIO.write(window.captureContent(), "png", new File(args[0]));
        }
    }

    private static Map<String, Object> def(String id, String primitive, String action, Map<String, Object> bindings, Map<String, Object> composition) {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("definitionId", id);
        fields.put("definitionVersion", 1);
        fields.put("definitionKey", id + "@1");
        fields.put("primitive", primitive);
        fields.put("action", action);
        fields.put("profile", "HUMAN_VISUAL");
        fields.put("bindings", bindings);
        fields.put("contentAddress", "demo:" + id);
        fields.put("metadata", Map.of("compositionHints", List.of(Map.of("layoutModel", "GRID12", "placement", composition))));
        return message("UI_DEFINITION", fields);
    }

    private static Map<String, Object> placement(int order, int span) {
        return Map.of("elementId", "demo", "region", "main", "order", order, "span", span, "rowSpan", 1, "align", "STRETCH", "viewportClass", "DEFAULT");
    }

    private static Map<String, Object> inst(String id, String key, String parent, Map<String, Object> slots) {
        return Map.of("instanceId", id, "definitionKey", key, "parentId", parent, "slots", slots);
    }

    private static Map<String, Object> message(String type, Map<String, Object> fields) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", type);
        result.put("protocolVersion", "WIRE-UI/0.1");
        result.putAll(fields);
        return result;
    }
}
