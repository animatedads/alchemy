package org.alchemy.wireui.swing;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class WireValues {
    private WireValues() {}

    static String text(Map<String, Object> map, String key, String fallback) {
        Object value = map == null ? null : map.get(key);
        return value == null ? fallback : String.valueOf(value);
    }

    static long longValue(Map<String, Object> map, String key, long fallback) {
        Object value = map == null ? null : map.get(key);
        if (value == null) return fallback;
        if (value instanceof Number number) return number.longValue();
        try { return Long.parseLong(String.valueOf(value)); }
        catch (NumberFormatException ex) { return fallback; }
    }

    static boolean bool(Object value, boolean fallback) {
        if (value == null) return fallback;
        if (value instanceof Boolean b) return b;
        String s = String.valueOf(value).trim();
        if (s.equalsIgnoreCase("true") || s.equals("1")) return true;
        if (s.equalsIgnoreCase("false") || s.equals("0")) return false;
        return fallback;
    }

    static Map<String, Object> map(Object value) {
        if (!(value instanceof Map<?, ?>)) return Map.of();
        @SuppressWarnings("unchecked")
        Map<String, Object> result = (Map<String, Object>) freeze(value, new IdentityHashMap<>());
        return result;
    }

    static List<Object> list(Object value) {
        if (value == null) return List.of();
        if (value instanceof List<?> || value instanceof Iterable<?> || value.getClass().isArray()) {
            @SuppressWarnings("unchecked")
            List<Object> result = (List<Object>) freeze(value, new IdentityHashMap<>());
            return result;
        }
        return List.of(value);
    }

    static Object freezeValue(Object value) {
        return freeze(value, new IdentityHashMap<>());
    }

    static List<Map<String, Object>> mapList(Object value) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (Object item : list(value)) {
            Map<String, Object> map = map(item);
            if (!map.isEmpty()) result.add(map);
        }
        return Collections.unmodifiableList(result);
    }

    private static Object freeze(Object value, IdentityHashMap<Object, Boolean> active) {
        if (value == null) return null;
        if (value instanceof Map<?, ?> map) {
            enter(value, active);
            try {
                Map<String, Object> result = new LinkedHashMap<>();
                for (Map.Entry<?, ?> entry : map.entrySet()) {
                    result.put(String.valueOf(entry.getKey()), freeze(entry.getValue(), active));
                }
                return Collections.unmodifiableMap(result);
            } finally { active.remove(value); }
        }
        if (value instanceof List<?> list) {
            enter(value, active);
            try {
                List<Object> result = new ArrayList<>(list.size());
                for (Object item : list) result.add(freeze(item, active));
                return Collections.unmodifiableList(result);
            } finally { active.remove(value); }
        }
        if (value instanceof Iterable<?> iterable) {
            enter(value, active);
            try {
                List<Object> result = new ArrayList<>();
                for (Object item : iterable) result.add(freeze(item, active));
                return Collections.unmodifiableList(result);
            } finally { active.remove(value); }
        }
        if (value.getClass().isArray()) {
            enter(value, active);
            try {
                int n = Array.getLength(value);
                List<Object> result = new ArrayList<>(n);
                for (int i = 0; i < n; i++) result.add(freeze(Array.get(value, i), active));
                return Collections.unmodifiableList(result);
            } finally { active.remove(value); }
        }
        return value;
    }

    private static void enter(Object value, IdentityHashMap<Object, Boolean> active) {
        if (active.put(value, Boolean.TRUE) != null) throw new IllegalArgumentException("cyclic Wire value is not supported");
    }
}
