package org.alchemy.wireui.swing;

import java.util.LinkedHashMap;
import java.util.Map;

public final class WireSwingProtocol {
    public static final String VERSION = "WIRE-UI/0.1";
    public static final String UI_HELLO = "UI_HELLO";
    public static final String UI_RENDER_PROFILE = "UI_RENDER_PROFILE";
    public static final String UI_DEFINITION_MANIFEST = "UI_DEFINITION_MANIFEST";
    public static final String UI_DEFINITION = "UI_DEFINITION";
    public static final String UI_DEFINITION_REQUIRED = "UI_DEFINITION_REQUIRED";
    public static final String UI_MATERIAL_SET = "UI_MATERIAL_SET";
    public static final String UI_JOURNEY_PLAN = "UI_JOURNEY_PLAN";
    public static final String UI_VIEW_SNAPSHOT = "UI_VIEW_SNAPSHOT";
    public static final String UI_VIEW_PATCH = "UI_VIEW_PATCH";
    public static final String UI_ACTION = "UI_ACTION";
    public static final String UI_RESYNC_REQUEST = "UI_RESYNC_REQUEST";
    public static final String UI_ERROR = "UI_ERROR";

    private WireSwingProtocol() {}

    public static Map<String, Object> message(String type) {
        Map<String, Object> message = new LinkedHashMap<>();
        message.put("type", type);
        message.put("protocolVersion", VERSION);
        return message;
    }
}
