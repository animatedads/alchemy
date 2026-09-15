package org.alchemy.wireui.swing;

import javax.swing.Timer;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Tiny in-process authority used only by the executable demonstration.
 *
 * <p>This deliberately sits outside {@link WireSwingRuntime}: the renderer
 * emits UI_ACTION and this demo authority decides which authoritative snapshot
 * follows. It therefore exercises journey switching without teaching Swing to
 * own journey state.</p>
 */
final class WireSwingStandaloneDemo {
    private static final String SEARCH = "SEARCH";
    private static final String SUMMARY = "SUMMARY";
    private static final String TRANSACTION = "TRANSACTION";

    private WireSwingStandaloneDemo() {}

    static WireSwingRuntime createRuntime() {
        WireSwingRuntime runtime = WireSwingRuntime.create();
        runtime.hello("standalone-demo", "local", "desktop");
        installDefinitions(runtime);
        runtime.accept(searchSnapshot(0, "PIK", "EWR", "2026-09-01", "2"));
        return runtime;
    }

    static Timer startAuthorityLoop(WireSwingRuntime runtime) {
        Timer timer = new Timer(40, event -> {
            Map<String, Object> action;
            while ((action = runtime.pollAction()) != null) handleAction(runtime, action);
        });
        timer.setRepeats(true);
        timer.start();
        return timer;
    }

    static void handleAction(WireSwingRuntime runtime, Map<String, Object> action) {
        String semanticAction = WireValues.text(action, "action", "");
        Map<String, Object> detail = WireValues.map(action.get("detail"));
        long revision = Math.max(0, runtime.revision() + 1);

        switch (semanticAction) {
            case "FLIGHT.SEARCH" -> runtime.accept(summarySnapshot(
                    revision,
                    WireValues.text(detail, "origin", "PIK"),
                    WireValues.text(detail, "destination", "EWR"),
                    WireValues.text(detail, "date", "2026-09-01"),
                    WireValues.text(detail, "passengers", "2")));
            case "DEMO.NAVIGATE" -> {
                String target = WireValues.text(detail, "value", SEARCH).toUpperCase();
                switch (target) {
                    case SUMMARY -> runtime.accept(summarySnapshot(revision, "PIK", "EWR", "2026-09-01", "2"));
                    case TRANSACTION -> runtime.accept(transactionSnapshot(revision));
                    default -> runtime.accept(searchSnapshot(revision, "PIK", "EWR", "2026-09-01", "2"));
                }
            }
            case "DEMO.CONFIRM" -> runtime.accept(transactionSnapshot(revision));
            case "DEMO.NEW_SEARCH" -> runtime.accept(searchSnapshot(revision, "PIK", "EWR", "2026-09-01", "2"));
            default -> { /* Demo authority ignores unknown semantic actions. */ }
        }
    }

    private static void installDefinitions(WireSwingRuntime runtime) {
        runtime.accept(def("ROOT", "PANEL", "", "", "", Map.of(), placement(0, 12)));
        runtime.accept(def("APP_HEADER", "TEXT", "", "", "heading", Map.of(), placement(10, 12)));
        runtime.accept(def("NAVIGATION", "LIST", "DEMO.NAVIGATE", "", "navigation", Map.of(), placement(20, 3)));
        runtime.accept(def("SEARCH_PANEL", "FORM", "FLIGHT.SEARCH", "Search flights", "primary-form",
                bindings("origin", "origin", "destination", "destination", "date", "date", "passengers", "passengers"), placement(30, 5)));
        runtime.accept(def("DETAIL_PANEL", "SEMANTIC_RECORD", "", "Flight detail", "detail-card",
                bindings("status", "status", "route", "route", "fare", "fare"), placement(40, 4)));
        runtime.accept(def("SUMMARY_PANEL", "SEMANTIC_RECORD", "", "Search summary", "detail-card",
                bindings("route", "route", "date", "date", "passengers", "passengers", "fare", "fare"), placement(30, 9)));
        runtime.accept(def("CONFIRM_BUTTON", "BUTTON", "DEMO.CONFIRM", "Book this fare", "primary-action", Map.of(), placement(40, 3)));
        runtime.accept(def("TRANSACTION_PANEL", "SEMANTIC_RECORD", "", "Transaction", "detail-card",
                bindings("status", "status", "reference", "reference", "route", "route", "amount", "amount"), placement(30, 9)));
        runtime.accept(def("NEW_SEARCH_BUTTON", "BUTTON", "DEMO.NEW_SEARCH", "New search", "primary-action", Map.of(), placement(40, 3)));
        runtime.accept(def("NOTICES", "STATUS", "", "", "status", Map.of(), placement(50, 12)));
    }

    private static Map<String, Object> searchSnapshot(long revision, String origin, String destination, String date, String passengers) {
        return snapshot(SEARCH, revision, List.of(
                inst("root", "ROOT@1", "", Map.of()),
                inst("header", "APP_HEADER@1", "root", Map.of("text", "Wire UI — Swing Desktop Renderer")),
                inst("nav", "NAVIGATION@1", "root", Map.of("items", List.of("Search", "Summary", "Transaction"), "ariaLabel", "Journey screens")),
                inst("search", "SEARCH_PANEL@1", "root", Map.of("origin", origin, "destination", destination, "date", date, "passengers", passengers, "ariaLabel", "Flight search")),
                inst("detail", "DETAIL_PANEL@1", "root", Map.of("status", "Ready", "route", origin + " → " + destination, "fare", "GBP 199.00")),
                inst("notices", "NOTICES@1", "root", Map.of("text", "WIRE-UI/0.1 • renderer emits actions; demo authority owns journey transitions"))));
    }

    private static Map<String, Object> summarySnapshot(long revision, String origin, String destination, String date, String passengers) {
        return snapshot(SUMMARY, revision, List.of(
                inst("root", "ROOT@1", "", Map.of()),
                inst("header", "APP_HEADER@1", "root", Map.of("text", "Flight summary")),
                inst("nav", "NAVIGATION@1", "root", Map.of("items", List.of("Search", "Summary", "Transaction"), "ariaLabel", "Journey screens")),
                inst("summary", "SUMMARY_PANEL@1", "root", Map.of(
                        "route", origin + " → " + destination,
                        "date", date,
                        "passengers", passengers,
                        "fare", "GBP 199.00")),
                inst("confirm", "CONFIRM_BUTTON@1", "root", Map.of()),
                inst("notices", "NOTICES@1", "root", Map.of("text", "Authoritative view: SUMMARY"))));
    }

    private static Map<String, Object> transactionSnapshot(long revision) {
        return snapshot(TRANSACTION, revision, List.of(
                inst("root", "ROOT@1", "", Map.of()),
                inst("header", "APP_HEADER@1", "root", Map.of("text", "Transaction complete")),
                inst("nav", "NAVIGATION@1", "root", Map.of("items", List.of("Search", "Summary", "Transaction"), "ariaLabel", "Journey screens")),
                inst("transaction", "TRANSACTION_PANEL@1", "root", Map.of(
                        "status", "Confirmed",
                        "reference", "WIRE-240901-001",
                        "route", "PIK → EWR",
                        "amount", "GBP 199.00")),
                inst("new-search", "NEW_SEARCH_BUTTON@1", "root", Map.of()),
                inst("notices", "NOTICES@1", "root", Map.of("text", "Authoritative view: TRANSACTION"))));
    }

    private static Map<String, Object> bindings(String... pairs) {
        if (pairs.length % 2 != 0) throw new IllegalArgumentException("binding pairs must be even");
        Map<String, Object> result = new LinkedHashMap<>();
        for (int i = 0; i < pairs.length; i += 2) result.put(pairs[i], pairs[i + 1]);
        return result;
    }

    private static Map<String, Object> def(
            String id, String primitive, String action, String label, String styleRole,
            Map<String, Object> bindings, Map<String, Object> composition) {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("definitionId", id);
        fields.put("definitionVersion", 1);
        fields.put("definitionKey", id + "@1");
        fields.put("primitive", primitive);
        fields.put("action", action);
        fields.put("label", label);
        fields.put("styleRole", styleRole);
        fields.put("profile", "HUMAN_VISUAL");
        fields.put("bindings", bindings);
        fields.put("contentAddress", "standalone:" + id);
        fields.put("metadata", Map.of("compositionHints", List.of(Map.of("layoutModel", "GRID12", "placement", composition))));
        return message("UI_DEFINITION", fields);
    }

    private static Map<String, Object> placement(int order, int span) {
        return Map.of(
                "elementId", "standalone-demo", "region", "main", "order", order,
                "span", span, "rowSpan", 1, "align", "STRETCH", "viewportClass", "DEFAULT");
    }

    private static Map<String, Object> inst(String id, String key, String parent, Map<String, Object> slots) {
        return Map.of("instanceId", id, "definitionKey", key, "parentId", parent, "slots", slots);
    }

    private static Map<String, Object> snapshot(String viewRef, long revision, List<Map<String, Object>> instances) {
        return message("UI_VIEW_SNAPSHOT", Map.of(
                "viewRef", viewRef, "revision", revision,
                "rootInstanceId", "root", "instances", instances));
    }

    private static Map<String, Object> message(String type, Map<String, Object> fields) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", type);
        result.put("protocolVersion", WireSwingProtocol.VERSION);
        result.putAll(fields);
        return result;
    }
}
