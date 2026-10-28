// SLAM Java reader fixture. Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
// javac compiles this file in run_tests.sh, so every construct here is real Java.
import java.util.List;
import java.util.Map;

public class Shapes {
    private double mutationRate;
    private double crossoverRate;
    private int count = 0, limit = 10;          // two fields in one declaration
    private final Object lock = new Object();
    private final Runnable r = () -> { count++; };   // a lambda body in a field: part of the field

    /* the same range check on two parameters: one node, two bindings (the GA test, in Java) */
    public Shapes(double mutationRate, double crossoverRate) {
        if (mutationRate < 0 || mutationRate > 1) throw new IllegalArgumentException("mutationRate");
        if (crossoverRate < 0 || crossoverRate > 1) {
            throw new IllegalArgumentException("crossoverRate");
        }
        this.mutationRate = mutationRate;
        this.crossoverRate = crossoverRate;
    }

    /* limit is a parameter here, so it hides the field: an A role, not an F role */
    int clamp(int limit) {
        if (count > limit) return limit;
        return count;
    }

    String kind(int code) {
        switch (code) {
            case 1: return "one";
            case 2:
            case 3: return "few";
            default: return "many";
        }
    }

    String arrow(int code) {
        return switch (code) { case 1 -> "one"; default -> "many"; };
    }

    int sum(List<Integer> values) {
        int total = 0;
        outer:
        for (int v : values) {
            if (v < 0) continue;
            if (v > 1_000_000) break outer;
            total += v;
        }
        int i = 0;
        do { i++; } while (i < 0x1F);
        synchronized (lock) { count += total; }
        return total;
    }

    String read(Map<String, Object> d) {
        try {
            Object v = d.get("key");
            if (v == null) return null;
            return v.toString();
        } catch (ClassCastException | IllegalStateException e) {
            return "";
        } finally {
            count++;
        }
    }

    static final String BLOCK = """
        a text block with "quotes" and a ; inside
        """;
    static final char QUOTE = '\'';
    static final double SMALL = 1e-5, HALF = .5f;

    enum Mode { ON("on") { @Override String label() { return "ON"; } }, OFF("off");
        private final String text;
        Mode(String text) { this.text = text; }
        String label() { return text; }
    }

    record Pair(String left, List<List<String>> right) {
        int size() { return right.size() + left.length(); }
    }
}
