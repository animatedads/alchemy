package org.alchemy.wireui.swing;

import java.awt.GraphicsEnvironment;
import java.awt.image.BufferedImage;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class WireSwingDesktopWindowTest {
    public static void main(String[] args) {
        if (GraphicsEnvironment.isHeadless()) throw new AssertionError("desktop test requires a display");
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.hello("desktop-test", "session", "swing");
        runtime.accept(message("UI_DEFINITION", Map.of(
                "definitionId", "ROOT", "definitionVersion", 1, "definitionKey", "ROOT@1", "primitive", "PANEL", "contentAddress", "root")));
        runtime.accept(message("UI_DEFINITION", Map.of(
                "definitionId", "TITLE", "definitionVersion", 1, "definitionKey", "TITLE@1", "primitive", "TEXT", "contentAddress", "title")));
        runtime.accept(message("UI_VIEW_SNAPSHOT", Map.of(
                "viewRef", "desktop-view", "revision", 0, "rootInstanceId", "root",
                "instances", List.of(
                        instance("root", "ROOT@1", "", Map.of()),
                        instance("title", "TITLE@1", "root", Map.of("text", "Wire UI Swing Desktop"))))));

        try (WireSwingDesktopWindow window = WireSwingDesktopWindow.create(runtime, "Wire UI Desktop Test", 800, 520)) {
            window.showWindow();
            if (!window.isDisplayable() || !window.isVisible()) throw new AssertionError("desktop window did not become visible");
            BufferedImage image = window.captureContent();
            if (image.getWidth() < 700 || image.getHeight() < 400) throw new AssertionError("unexpected capture size " + image.getWidth() + "x" + image.getHeight());
            int[][] sizes = { {360, 260}, {1280, 760}, {640, 420}, {900, 560} };
            for (int[] size : sizes) {
                window.resizeWindow(size[0], size[1]);
                BufferedImage resized = window.captureContent();
                if (resized.getWidth() < 300 || resized.getHeight() < 200) {
                    throw new AssertionError("resize capture collapsed at " + size[0] + "x" + size[1]);
                }
            }
        }
        System.out.println("PASS WireSwingDesktopWindow visible/capture/resize-stress/dispose");
    }

    private static Map<String, Object> instance(String id, String key, String parent, Map<String, Object> slots) {
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
