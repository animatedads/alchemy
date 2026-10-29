// Untested-report fixture: named by the build script the test runs.
int helperTwice(int x) { return 2 * x; }
int helperNever(int x) { return x; }
int helperUser(int x) { return helperTwice(x); }
