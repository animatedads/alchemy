// Untested-report fixture: named by the build script the test runs.
int helperTwice(int x) { return 2 * x; }
int helperNever(int x) { return x; }
int helperUser(int x) { return helperTwice(x); }
// installed by its address: no call names it, but it is used
using Hook = int (*)(int);
inline Hook &hook() { static Hook h = nullptr; return h; }
int helperByPointer(int x) { return x * 3; }
inline const bool helperInstalled = (hook() = &helperByPointer, true);
