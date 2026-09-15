package com.federationbank.atm.ui;

/** Optional ANSI approximation of the supplied FederationBank roundel. */
public final class TerminalBranding {
    private static final String RESET = "\u001b[0m";
    private static final String GOLD = "\u001b[38;5;220m";
    private static final String RED = "\u001b[38;5;196m";

    private TerminalBranding() {}

    public static String banner(boolean ansi) {
        if (!ansi) return "          FEDERATION BANK\n\n        From the bank that cares :)\n";
        String g = GOLD, r = RED, z = RESET;
        return "\n" +
                g + "              ███████████████\n" +
                "          ███████████████████████\n" +
                "       █████████████████████████████\n" +
                "     █████" + r + "       ██" + g + "████████████████\n" +
                "    ████" + r + "     ███████  ██" + g + "████████████\n" +
                "   ███" + r + "    █████████████" + g + "████████████\n" +
                "  ███" + r + "    ███████████████" + g + "███████████\n" +
                "  ███" + r + "      █████████████" + g + "███████████\n" +
                "   ███" + r + "       ███████████" + g + "███████████\n" +
                "    ████" + r + "        ████████" + g + "████████████\n" +
                "      █████████" + r + "   ██" + g + "██████████████\n" +
                "        █████████" + r + " ██" + g + "███████████\n" +
                "           █████████████████████\n" +
                "                ███████████\n" + z +
                "\n              FEDERATION BANK\n" +
                "            From the bank that cares :)\n";
    }
}
