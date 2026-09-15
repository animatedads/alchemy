package com.federationbank.atm.protocol;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/** Minimal dependency-free JSON codec used by the ATM wire protocol and journal. */
public final class Json {
    private Json() {}

    public static String stringify(Object value) {
        StringBuilder out = new StringBuilder();
        write(value, out, false);
        return out.toString();
    }

    /** Canonical JSON: object keys sorted recursively; used for bank rule signatures. */
    public static String canonical(Object value) {
        StringBuilder out = new StringBuilder();
        write(value, out, true);
        return out.toString();
    }

    @SuppressWarnings("unchecked")
    private static void write(Object value, StringBuilder out, boolean canonical) {
        if (value == null) {
            out.append("null");
        } else if (value instanceof String s) {
            string(s, out);
        } else if (value instanceof Boolean || value instanceof Integer || value instanceof Long
                || value instanceof Short || value instanceof Byte) {
            out.append(value);
        } else if (value instanceof Number n) {
            double d = n.doubleValue();
            if (!Double.isFinite(d)) throw new IllegalArgumentException("non-finite JSON number");
            out.append(value);
        } else if (value instanceof Map<?, ?> map) {
            out.append('{');
            Map<String, Object> values = new LinkedHashMap<>();
            for (Map.Entry<?, ?> e : map.entrySet()) values.put(String.valueOf(e.getKey()), e.getValue());
            List<String> keys = new ArrayList<>(values.keySet());
            if (canonical) Collections.sort(keys);
            boolean first = true;
            for (String key : keys) {
                if (!first) out.append(',');
                first = false;
                string(key, out);
                out.append(':');
                write(values.get(key), out, canonical);
            }
            out.append('}');
        } else if (value instanceof Iterable<?> iterable) {
            out.append('[');
            boolean first = true;
            for (Object item : iterable) {
                if (!first) out.append(',');
                first = false;
                write(item, out, canonical);
            }
            out.append(']');
        } else if (value.getClass().isArray()) {
            Object[] array = (Object[]) value;
            write(List.of(array), out, canonical);
        } else {
            throw new IllegalArgumentException("unsupported JSON value: " + value.getClass());
        }
    }

    private static void string(String s, StringBuilder out) {
        out.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> out.append("\\\"");
                case '\\' -> out.append("\\\\");
                case '\b' -> out.append("\\b");
                case '\f' -> out.append("\\f");
                case '\n' -> out.append("\\n");
                case '\r' -> out.append("\\r");
                case '\t' -> out.append("\\t");
                default -> {
                    if (c < 0x20) out.append(String.format("\\u%04x", (int)c));
                    else out.append(c);
                }
            }
        }
        out.append('"');
    }

    public static Object parse(String text) {
        return new Parser(text).parse();
    }

    @SuppressWarnings("unchecked")
    public static Map<String, Object> parseObject(String text) {
        Object value = parse(text);
        if (!(value instanceof Map<?, ?>)) throw new IllegalArgumentException("JSON object required");
        return (Map<String, Object>) value;
    }

    private static final class Parser {
        private final String text;
        private int p;

        Parser(String text) { this.text = text; }

        Object parse() {
            ws();
            Object value = value();
            ws();
            if (p != text.length()) fail("trailing data");
            return value;
        }

        private Object value() {
            ws();
            if (p >= text.length()) return fail("unexpected end");
            char c = text.charAt(p);
            return switch (c) {
                case '{' -> object();
                case '[' -> array();
                case '"' -> string();
                case 't' -> literal("true", Boolean.TRUE);
                case 'f' -> literal("false", Boolean.FALSE);
                case 'n' -> literal("null", null);
                default -> number();
            };
        }

        private Map<String, Object> object() {
            LinkedHashMap<String, Object> map = new LinkedHashMap<>();
            p++;
            ws();
            if (peek('}')) { p++; return map; }
            while (true) {
                ws();
                if (!peek('"')) return fail("object key required");
                String key = string();
                ws();
                expect(':');
                map.put(key, value());
                ws();
                if (peek('}')) { p++; return map; }
                expect(',');
            }
        }

        private List<Object> array() {
            ArrayList<Object> list = new ArrayList<>();
            p++;
            ws();
            if (peek(']')) { p++; return list; }
            while (true) {
                list.add(value());
                ws();
                if (peek(']')) { p++; return list; }
                expect(',');
            }
        }

        private String string() {
            expect('"');
            StringBuilder out = new StringBuilder();
            while (p < text.length()) {
                char c = text.charAt(p++);
                if (c == '"') return out.toString();
                if (c == '\\') {
                    if (p >= text.length()) return fail("bad escape");
                    char e = text.charAt(p++);
                    switch (e) {
                        case '"', '\\', '/' -> out.append(e);
                        case 'b' -> out.append('\b');
                        case 'f' -> out.append('\f');
                        case 'n' -> out.append('\n');
                        case 'r' -> out.append('\r');
                        case 't' -> out.append('\t');
                        case 'u' -> {
                            if (p + 4 > text.length()) return fail("bad unicode escape");
                            out.append((char) Integer.parseInt(text.substring(p, p + 4), 16));
                            p += 4;
                        }
                        default -> { return fail("bad escape"); }
                    }
                } else out.append(c);
            }
            return fail("unterminated string");
        }

        private Object number() {
            int start = p;
            if (peek('-')) p++;
            while (p < text.length() && Character.isDigit(text.charAt(p))) p++;
            boolean decimal = false;
            if (peek('.')) {
                decimal = true; p++;
                while (p < text.length() && Character.isDigit(text.charAt(p))) p++;
            }
            if (peek('e') || peek('E')) {
                decimal = true; p++;
                if (peek('+') || peek('-')) p++;
                while (p < text.length() && Character.isDigit(text.charAt(p))) p++;
            }
            if (start == p) return fail("number expected");
            String token = text.substring(start, p);
            try {
                /* Keep integer JSON tokens as Long.  Do not use a Double/Long
                 * conditional expression here: Java numeric unboxing/promotion
                 * would turn both branches into Double, changing signed canonical
                 * JSON such as 50000 into 50000.0 after a wire round-trip. */
                if (decimal) return Double.valueOf(token);
                return Long.valueOf(token);
            } catch (NumberFormatException e) { return fail("invalid number"); }
        }

        private Object literal(String token, Object value) {
            if (!text.startsWith(token, p)) return fail("invalid literal");
            p += token.length();
            return value;
        }

        private void ws() { while (p < text.length() && Character.isWhitespace(text.charAt(p))) p++; }
        private boolean peek(char c) { return p < text.length() && text.charAt(p) == c; }
        private void expect(char c) { if (!peek(c)) fail("expected '" + c + "'"); p++; }
        private <T> T fail(String message) { throw new IllegalArgumentException(message + " at character " + p); }
    }
}
